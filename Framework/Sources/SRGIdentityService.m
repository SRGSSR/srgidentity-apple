//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityService.h"
#import "SRGIdentityService+Private.h"

#import <UICKeyChainStore/UICKeyChainStore.h>

static SRGIdentityService *s_currentIdentityService;

NSString * const SRGIdentityServiceUserLoggedInNotification = @"SRGIdentityServiceUserLoggedInNotification";
NSString * const SRGIdentityServiceUserLoggedOutNotification = @"SRGIdentityServiceUserLoggedOutNotification";
NSString * const SRGIdentityServiceUserMetadatasUpdateNotification = @"SRGIdentityServiceUserMetadatasUpdateNotification";

NSString * const SRGIdentityServiceEmailAddressKey = @"SRGIdentityServiceEmailAddressKey";

NSString * const SRGServiceIdentifierEmailStoreKey = @"email";
NSString * const SRGServiceIdentifierSessionTokenStoreKey = @"sessionToken";
NSString * const SRGServiceIdentifierUserIdStoreKey = @"userId";
NSString * const SRGServiceIdentifierDisplayNameStoreKey = @"displayName";

NSString * const SRGServiceIdentifierCookieName = @"identity.provider.sid";

@interface SRGIdentityService ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) UICKeyChainStore *keyChainStore;

@property (nonatomic, readonly) NSString *serviceIdentifier;

@property (nonatomic) NSURLSessionTask *profileSessionTask;

@end

@implementation SRGIdentityService

#pragma mark Class methods

+ (SRGIdentityService *)currentIdentityService
{
    return s_currentIdentityService;
}

+ (SRGIdentityService *)setCurrentIdentityService:(SRGIdentityService *)currentIdentityService
{
    SRGIdentityService *previousidentityService= s_currentIdentityService;
    s_currentIdentityService = currentIdentityService;
    return previousidentityService;
}

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL accessGroup:(nullable NSString *)accessGroup
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        
        self.keyChainStore = [UICKeyChainStore keyChainStoreWithService:self.serviceIdentifier accessGroup:accessGroup];
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
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

- (NSString *)displayName
{
    return [self.keyChainStore stringForKey:SRGServiceIdentifierDisplayNameStoreKey] ?: self.emailAddress;
}

- (NSString *)userId
{
    return [self.keyChainStore stringForKey:SRGServiceIdentifierUserIdStoreKey];
}

- (NSString *)serviceIdentifier
{
    NSArray *hostSplited = [self.serviceURL.host componentsSeparatedByString:@"."];
    NSArray *reverseHostSplited = [[hostSplited reverseObjectEnumerator] allObjects];
    NSString *domain = [reverseHostSplited componentsJoinedByString:@"."];
    return  [domain stringByAppendingString:@".identity"];
}

#pragma mark Services

- (NSURLSessionTask *)accountWithCompletionBlock:(SRGAccountCompletionBlock)completionBlock
{
    NSURL *URL = [NSURL URLWithString:@"api/v2/session/user/profile" relativeToURL:self.serviceURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    NSString *sessionToken = [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey];
    if (sessionToken) {
        [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    }
    
    // TODO: Proper error codes and domain. Factor out common requewst logic if possible / meaningful
    return [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        SRGAccountCompletionBlock requestCompletionBlock = ^(SRGAccount * _Nullable account, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (account) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserMetadatasUpdateNotification
                                                                        object:self
                                                                      userInfo:@{ SRGIdentityServiceEmailAddressKey : account.emailAddress ?: NSNull.null }];
                }
                completionBlock(account, error);
            });
        };
        
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
            return;
        }
        else if (error) {
            requestCompletionBlock(nil, error);
            return;
        }
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
            NSInteger HTTPStatusCode = HTTPURLResponse.statusCode;
            
            // Properly handle HTTP error codes >= 400 as real errors
            if (HTTPStatusCode >= 400) {
                NSError *HTTPError = [NSError errorWithDomain:@"http" code:HTTPStatusCode userInfo:nil];
                requestCompletionBlock(nil, HTTPError);
                return;
            }
        }
        
        id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if (! [JSONObject isKindOfClass:[NSDictionary class]]) {
            requestCompletionBlock(nil, [NSError errorWithDomain:@"format" code:1012 userInfo:nil]);
            return;
        }
        NSDictionary *user = JSONObject[@"user"];
        SRGAccount *account = [MTLJSONAdapter modelOfClass:[SRGAccount class] fromJSONDictionary:user error:&error];
        if (! account) {
            requestCompletionBlock(nil, [NSError errorWithDomain:@"parsing" code:1012 userInfo:nil]);
            return;
        }
        
        NSString *emailAddress = self.emailAddress;
        if (!self.emailAddress || ![account.emailAddress isEqualToString:emailAddress]) {
            [self.keyChainStore setString:account.emailAddress forKey:SRGServiceIdentifierEmailStoreKey];
        }
        [self.keyChainStore setString:account.displayName forKey:SRGServiceIdentifierDisplayNameStoreKey];
        NSString *uid = account.uid ? account.uid.stringValue : nil;
        [self.keyChainStore setString:uid forKey:SRGServiceIdentifierUserIdStoreKey];
        
        requestCompletionBlock(account, nil);
    }];
}

- (void)logout
{
    NSString *emailAddress = self.emailAddress;
    
    [UICKeyChainStore removeAllItemsForService:self.serviceIdentifier];
    
    [self.keyChainStore setString:emailAddress forKey:SRGServiceIdentifierEmailStoreKey];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserLoggedOutNotification
                                                        object:self
                                                      userInfo:@{ SRGIdentityServiceEmailAddressKey : emailAddress ?: NSNull.null }];
}

#pragma mark Private

- (void)loggedWithSessionToken:(NSString *)sessionToken
{
    [self.keyChainStore setString:sessionToken forKey:SRGServiceIdentifierSessionTokenStoreKey];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *emailAddress = self.emailAddress;
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserLoggedInNotification
                                                            object:self
                                                          userInfo:@{ SRGIdentityServiceEmailAddressKey : emailAddress ?: NSNull.null }];
    });
    
    self.profileSessionTask = [self accountWithCompletionBlock:^(SRGAccount * _Nullable account, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *emailAddress = self.emailAddress;
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserMetadatasUpdateNotification
                                                                object:self
                                                              userInfo:@{ SRGIdentityServiceEmailAddressKey : emailAddress ?: NSNull.null }];
        });
    }];
    [self.profileSessionTask resume];
}

@end
