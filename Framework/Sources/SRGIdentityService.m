//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityService.h"

#import "NSBundle+SRGIdentity.h"
#import "SRGIdentityError.h"
#import "SRGIdentityLogger.h"

#import <AuthenticationServices/AuthenticationServices.h>
#import <libextobjc/libextobjc.h>
#import <SafariServices/SafariServices.h>
#import <SRGNetwork/SRGNetwork.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import <UIKit/UIKit.h>

typedef void (^SRGAccountCompletionBlock)(SRGAccount * _Nullable account, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);

static SRGIdentityService *s_currentIdentityService;

NSString * const SRGIdentityServiceUserDidLoginNotification = @"SRGIdentityServiceUserDidLoginNotification";
NSString * const SRGIdentityServiceUserDidLogoutNotification = @"SRGIdentityServiceUserDidLogoutNotification";
NSString * const SRGIdentityServiceDidUpdateAccountNotification = @"SRGIdentityServiceDidUpdateAccountNotification";
NSString * const SRGIdentityServiceUserLoginDidFailNotification = @"SRGIdentityServiceUserLoginDidFailNotification";

NSString * const SRGIdentityServiceAccountKey = @"SRGIdentityServiceAccount";
NSString * const SRGIdentityServiceErrorKey = @"SRGIdentityServiceError";

NSString * const SRGServiceIdentifierEmailStoreKey = @"email";
NSString * const SRGServiceIdentifierSessionTokenStoreKey = @"sessionToken";

NSString * const SRGServiceIdentifierCookieName = @"identity.provider.sid";

@interface SRGIdentityService () <SFSafariViewControllerDelegate>

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) UICKeyChainStore *keyChainStore;

@property (nonatomic, readonly) NSString *serviceIdentifier;

@property (nonatomic) SRGNetworkRequest *profileRequest;

@property (nonatomic) SRGAccount *account;

@property (nonatomic, weak) id authenticationSession /* ASWebAuthenticationSession or SFAuthenticationSession */;
@property (nonatomic, copy) NSString *identifier;

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

+ (NSString *)applicationURLScheme
{
    static NSString *URLScheme;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        NSArray *bundleURLTypes = NSBundle.mainBundle.infoDictionary[@"CFBundleURLTypes"];
        NSArray<NSString *> *bundleURLSchemes = bundleURLTypes.firstObject[@"CFBundleURLSchemes"];
        URLScheme = bundleURLSchemes.firstObject;
        if (! URLScheme) {
            SRGIdentityLogError(@"authentication", @"No URL scheme declared in your application Info.plist file under the "
                                "'CFBundleURLTypes' key. The application must at least contains one item with one scheme "
                                "to allow a correct authentication workflow. Take care to have an unique URL scheme.");
        }
    });
    return URLScheme;
}

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL accessGroup:(NSString *)accessGroup
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

#pragma clang diagnostic pop

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

#pragma mark URLs

- (NSURL *)loginRedirectURLWithIdentifier:(NSString *)identifier
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.serviceURL resolvingAgainstBaseURL:YES];
    NSArray<NSURLQueryItem *> *queryItems = URLComponents.queryItems ?: @[];
    URLComponents.queryItems = [queryItems arrayByAddingObject:[[NSURLQueryItem alloc] initWithName:@"client" value:identifier]];
    URLComponents.scheme = [SRGIdentityService applicationURLScheme];
    return URLComponents.URL;
}

- (NSURL *)loginRequestURLWithEmailAddress:(NSString *)emailAddress identifier:(NSString *)identifier
{
    NSURL *requestURL = [NSURL URLWithString:@"responsive/login" relativeToURL:self.serviceURL];
    NSURL *redirectURL = [self loginRedirectURLWithIdentifier:identifier];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:requestURL resolvingAgainstBaseURL:YES];
    NSArray<NSURLQueryItem *> *queryItems = @[[[NSURLQueryItem alloc] initWithName:@"withcode" value:@"true"],
                                              [[NSURLQueryItem alloc] initWithName:@"redirect" value:redirectURL.absoluteString]];
    if (emailAddress) {
        NSURLQueryItem *emailQueryItem = [[NSURLQueryItem alloc] initWithName:@"email" value:emailAddress];
        queryItems = [queryItems arrayByAddingObject:emailQueryItem];
    }
    URLComponents.queryItems = queryItems;
    return URLComponents.URL;
}

- (BOOL)shouldHandleReponseURL:(NSURL *)URL forRequestWithIdentifier:(NSString *)identifier
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"client"];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    if (queryItem && ! [identifier isEqualToString:queryItem.value]) {
        return NO;
    }
    
    NSURL *standardizedURL = [URL standardizedURL];
    NSURL *standardizedRedirectURL = [[self loginRedirectURLWithIdentifier:identifier] standardizedURL];
    
    return [standardizedURL.scheme isEqualToString:standardizedRedirectURL.scheme]
        && [standardizedURL.host isEqualToString:standardizedRedirectURL.host]
        && [standardizedURL.path isEqual:standardizedRedirectURL.path];
}

- (NSString *)tokenFromURL:(NSURL *)URL
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"token"];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    return queryItem.value;
}

#pragma mark Login / logout

// TODO: Prevent concurrent login attempts, or cancel previous one. Also prevent or govern interactions with logout
- (BOOL)loginWithEmailAddress:(NSString *)emailAddress
{
    NSString *identifier = NSUUID.UUID.UUIDString;
    NSURL *requestURL = [self loginRequestURLWithEmailAddress:emailAddress identifier:identifier];
    
    void (^completionHandler)(NSURL * _Nullable, NSError * _Nullable) = ^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
        NSAssert(NSThread.isMainThread, @"Main thread expected");
        
        if (error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserLoginDidFailNotification
                                                                object:self
                                                              userInfo:@{ SRGIdentityServiceErrorKey : error }];
            return;
        }
        
        [self handleCallbackURL:callbackURL withIdentifier:identifier];
    };
    
    // iOS 12 and later, use `ASWebAuthenticationSession`
    if (@available(iOS 12.0, *)) {
        ASWebAuthenticationSession *authenticationSession = [[ASWebAuthenticationSession alloc] initWithURL:requestURL
                                                                                          callbackURLScheme:[SRGIdentityService applicationURLScheme]
                                                                                          completionHandler:completionHandler];
        self.authenticationSession = authenticationSession;
        if (! [authenticationSession start]) {
            return NO;
        }
    }
    // iOS 11, use `SFAuthenticationSession`
    else if (@available(iOS 11.0, *)) {
        SFAuthenticationSession *authenticationSession = [[SFAuthenticationSession alloc] initWithURL:requestURL
                                                                                    callbackURLScheme:[SRGIdentityService applicationURLScheme]
                                                                                    completionHandler:completionHandler];
        self.authenticationSession = authenticationSession;
        if (! [authenticationSession start]) {
            return NO;
        }
    }
    // iOS 9 and 10, use `SFSafariViewController`
    else {
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:requestURL entersReaderIfAvailable:NO];
        safariViewController.delegate = self;
        // TODO: Use top root view controller
        UIViewController *presentingViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
        [presentingViewController presentViewController:safariViewController animated:YES completion:nil];
    }
    
    return YES;
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

#pragma mark Callback URL handling

- (BOOL)handleCallbackURL:(NSURL *)callbackURL withIdentifier:(NSString *)identifier
{
    if (! [self shouldHandleReponseURL:callbackURL forRequestWithIdentifier:identifier]) {
        return NO;
    }
    
    NSString *token = [self tokenFromURL:callbackURL];
    if (! token) {
        NSError *tokenError = [NSError errorWithDomain:SRGIdentityErrorDomain
                                                  code:SRGIdentityErrorCodeInvalidData
                                              userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"The authentication data is invalid.", @"Error message returned when an authentication server response data is incorrect.") }];
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserLoginDidFailNotification
                                                            object:self
                                                          userInfo:@{ SRGIdentityServiceErrorKey : tokenError }];
        return YES;
    }
    
    [self.keyChainStore setString:token forKey:SRGServiceIdentifierSessionTokenStoreKey];
    [self updateAccount];
    
    return YES;
}

#pragma mark Account information

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

#pragma mark SFSafariViewControllerDelegate protocol

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    // TODO:
#if 0
    id<SRGAuthenticationDelegate> delegate = self.delegate;
    [self cleanUp];
    NSError *error = [NSError errorWithDomain:SRGIdentityErrorDomain
                                         code:SRGAuthenticationCancelled
                                     userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"authentication cancelled.", @"Error message returned when the user or the app cancelled the authentication process.") }];
    [delegate failAuthenticationWithError:error];
#endif
}

@end
