//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityService.h"

#import "NSBundle+SRGIdentity.h"
#import "SRGAuthenticationController.h"
#import "SRGIdentityError.h"

#import <libextobjc/libextobjc.h>
#import <UICKeyChainStore/UICKeyChainStore.h>

typedef void (^SRGAccountCompletionBlock)(SRGAccount * _Nullable account, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);

static SRGIdentityService *s_currentIdentityService;

NSString * const SRGIdentityServiceUserDidLoginNotification = @"SRGIdentityServiceUserDidLoginNotification";
NSString * const SRGIdentityServiceUserDidLogoutNotification = @"SRGIdentityServiceUserDidLogoutNotification";
NSString * const SRGIdentityServiceDidUpdateAccountNotification = @"SRGIdentityServiceDidUpdateAccountNotification";

NSString * const SRGIdentityServiceAccountKey = @"SRGIdentityServiceAccount";

NSString * const SRGServiceIdentifierEmailStoreKey = @"email";
NSString * const SRGServiceIdentifierSessionTokenStoreKey = @"sessionToken";

NSString * const SRGServiceIdentifierCookieName = @"identity.provider.sid";

@interface SRGIdentityService ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) UICKeyChainStore *keyChainStore;

@property (nonatomic, readonly) NSString *serviceIdentifier;

@property (nonatomic) SRGNetworkRequest *profileRequest;

@property (nonatomic) SRGAccount *account;

@property (nonatomic) SRGAuthenticationController *authenticationController;
@property (nonatomic) SRGAuthenticationCompletionBlock authenticationCompletionBlock;

@end

@implementation SRGIdentityService

#pragma mark Class methods

+ (SRGIdentityService *)currentIdentityService
{
    return s_currentIdentityService;
}

+ (void)setCurrentIdentityService:(SRGIdentityService *)currentIdentityService
{
    s_currentIdentityService = currentIdentityService;
}

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL accessGroup:(nullable NSString *)accessGroup
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        self.keyChainStore = [UICKeyChainStore keyChainStoreWithService:self.serviceIdentifier accessGroup:accessGroup];
        [self updateAccount];
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithServiceURL:[NSURL new] accessGroup:nil];
}

#pragma mark Getters and setters

- (BOOL)isLogged
{
    return (self.sessionToken != nil);
}

- (NSString *)sessionToken
{
    return [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey];
}

- (NSString *)emailAddress
{
    return [self.keyChainStore stringForKey:SRGServiceIdentifierEmailStoreKey];
}

- (NSString *)serviceIdentifier
{
    NSArray *hostComponents = [self.serviceURL.host componentsSeparatedByString:@"."];
    NSArray *reverseHostComponents = [[hostComponents reverseObjectEnumerator] allObjects];
    NSString *domain = [reverseHostComponents componentsJoinedByString:@"."];
    return [domain stringByAppendingString:@".identity"];
}

#pragma mark Services

- (void)updateAccount
{
    NSURL *URL = [NSURL URLWithString:@"api/v2/session/user/profile" relativeToURL:self.serviceURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    NSString *sessionToken = [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey];
    if (sessionToken) {
        [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    }
    
    [[[SRGNetworkRequest alloc] initWithJSONDictionaryURLRequest:request session:NSURLSession.sharedSession options:0 completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        NSDictionary *user = JSONDictionary[@"user"];
        SRGAccount *account = [MTLJSONAdapter modelOfClass:SRGAccount.class fromJSONDictionary:user error:NULL];
        if (! account) {
            return;
        }
        
        self.account = account;
        [self.keyChainStore setString:account.emailAddress forKey:SRGServiceIdentifierEmailStoreKey];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceDidUpdateAccountNotification
                                                            object:self
                                                          userInfo:@{ SRGIdentityServiceAccountKey : account }];
    }] resume];
}

- (BOOL)presentauthenticationViewControllerFromViewController:(UIViewController *)presentingViewController
                                                completionBlock:(SRGAuthenticationCompletionBlock)completionBlock
{
    self.authenticationCompletionBlock = completionBlock;
    SRGAuthenticationRequest *request = [[SRGAuthenticationRequest alloc] initWithServiceURL:self.serviceURL emailAddress:self.emailAddress];
    self.authenticationController = [[SRGAuthenticationController alloc] initWithPresentingViewController:presentingViewController];
    return [self.authenticationController presentControllerWithRequest:request delegate:self];
}

- (void)logout
{
    SRGAccount *account = self.account;
    
    [UICKeyChainStore removeAllItemsForService:self.serviceIdentifier];
    self.account = nil;
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[SRGIdentityServiceAccountKey] = account;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                        object:self
                                                      userInfo:[userInfo copy]];
}

#pragma mark Private

- (void)loggedWithSessionToken:(NSString *)sessionToken
{
    [self.keyChainStore setString:sessionToken forKey:SRGServiceIdentifierSessionTokenStoreKey];
    [self updateAccount];
}

#pragma SRGAuthenticationDelegate delegate

- (void)cancelauthentication
{
    [self.authenticationController dismissExternalUserAgentAnimated:YES completion:^{
        NSError *error = [NSError errorWithDomain:SRGIdentityErrorDomain
                                             code:SRGAuthenticationCanceled
                                         userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"authentication canceled.", @"Error message returned when the user or the app canceled the authentication process.") }];
        [self didFinishWithError:error];
    }];
}

- (BOOL)resumeauthenticationWithURL:(NSURL *)URL
{
    // rejects URLs that don't match redirect (these may be completely unrelated to the authorization)
    if (![self.authenticationController.request shouldHandleReponseURL:URL]) {
        return NO;
    }
    
    NSError *error = nil;
    
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"token"];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    if (queryItem) {
        [self loggedWithSessionToken:queryItem.value];
    }
    else {
        error = [NSError errorWithDomain:SRGIdentityErrorDomain
                                    code:SRGIdentityErrorCodeInvalidData
                                userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"The authentication data is invalid.", @"Error message returned when an authentication server response data is incorrect.") }];
    }
    
    [self.authenticationController dismissExternalUserAgentAnimated:YES completion:^{
        [self didFinishWithError:error];
    }];
    
    return YES;
}

- (void)failauthenticationWithError:(NSError *)error
{
    [self didFinishWithError:error];
}

- (void)didFinishWithError:(nullable NSError *)error
{
    SRGAuthenticationCompletionBlock authenticationCompletionBlock = self.authenticationCompletionBlock;
    
    self.authenticationCompletionBlock = nil;
    self.authenticationController = nil;
    
    if (authenticationCompletionBlock) {
        authenticationCompletionBlock(error);
    }
}

@end
