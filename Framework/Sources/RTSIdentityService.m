//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RTSIdentityService.h"
#import "RTSIdentityService+Private.h"

#import <UICKeyChainStore/UICKeyChainStore.h>

static RTSIdentityService *s_currentIdentityService;

NSString * const RTSIdentityServiceUserLoggedInNotification = @"RTSIdentityServiceUserLoggedInNotification";
NSString * const RTSIdentityServiceUserLoggedOutNotification = @"RTSIdentityServiceUserLoggedOutNotification";
NSString * const RTSIdentityServiceUserMetadatasUpdateNotification = @"RTSIdentityServiceUserMetadatasUpdateNotification";

NSString * const RTSIdentityServiceEmailAddressKey = @"RTSIdentityServiceEmailAddressKey";

NSString * const ServiceIdentifierEmailStoreKey = @"email";
NSString * const ServiceIdentifierSessionTokenStoreKey = @"sessionToken";
NSString * const ServiceIdentifierUserIdStoreKey = @"userId";
NSString * const ServiceIdentifierDisplayNameStoreKey = @"displayName";

@interface RTSIdentityService ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) UICKeyChainStore *keyChainStore;

@property (nonatomic, readonly) NSString *serviceIdentifier;

@property (nonatomic) NSURLSessionTask *profileSessionTask;

@end

@implementation RTSIdentityService

#pragma mark Class methods

+ (RTSIdentityService *)currentIdentityService
{
    return s_currentIdentityService;
}

+ (RTSIdentityService *)setCurrentIdentityService:(RTSIdentityService *)currentIdentityService
{
    RTSIdentityService *previousidentityService= s_currentIdentityService;
    s_currentIdentityService = currentIdentityService;
    return previousidentityService;
}

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        
        self.keyChainStore = [UICKeyChainStore keyChainStoreWithService:self.serviceIdentifier accessGroup:nil];
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
    return [self.keyChainStore stringForKey:ServiceIdentifierSessionTokenStoreKey];
}

- (NSString *)emailAddress
{
    return [self.keyChainStore stringForKey:ServiceIdentifierEmailStoreKey];
}

- (NSString *)displayName
{
    return [self.keyChainStore stringForKey:ServiceIdentifierDisplayNameStoreKey] ?: self.emailAddress;
}

- (NSString *)userId
{
    return [self.keyChainStore stringForKey:ServiceIdentifierUserIdStoreKey];
}

- (NSString *)serviceIdentifier
{
    NSArray *hostSplited = [self.serviceURL.host componentsSeparatedByString:@"."];
    NSArray *reverseHostSplited = [[hostSplited reverseObjectEnumerator] allObjects];
    NSString *domain = [reverseHostSplited componentsJoinedByString:@"."];
    return  [domain stringByAppendingString:@".identity"];
}

#pragma mark Services

- (NSURLSessionTask *)accountWithCompletionBlock:(RTSAccountCompletionBlock)completionBlock
{
    NSURL *URL = [NSURL URLWithString:@"api/v2/session/user/profile" relativeToURL:self.serviceURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    NSString *sessionToken = [self.keyChainStore stringForKey:ServiceIdentifierSessionTokenStoreKey];
    if (sessionToken) {
        [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    }
    
    // TODO: Proper error codes and domain. Factor out common requewst logic if possible / meaningful
    return [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        RTSAccountCompletionBlock requestCompletionBlock = ^(RTSAccount * _Nullable account, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (account) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:RTSIdentityServiceUserMetadatasUpdateNotification
                                                                        object:self
                                                                      userInfo:@{ RTSIdentityServiceEmailAddressKey : account.emailAddress ?: NSNull.null }];
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
        RTSAccount *account = [MTLJSONAdapter modelOfClass:[RTSAccount class] fromJSONDictionary:user error:&error];
        if (! account) {
            requestCompletionBlock(nil, [NSError errorWithDomain:@"parsing" code:1012 userInfo:nil]);
            return;
        }
        
        NSString *emailAddress = self.emailAddress;
        if (!self.emailAddress || ![account.emailAddress isEqualToString:emailAddress]) {
            [self.keyChainStore setString:account.emailAddress forKey:ServiceIdentifierEmailStoreKey];
        }
        [self.keyChainStore setString:account.displayName forKey:ServiceIdentifierDisplayNameStoreKey];
        NSString *uid = account.uid ? account.uid.stringValue : nil;
        [self.keyChainStore setString:uid forKey:ServiceIdentifierUserIdStoreKey];
        
        requestCompletionBlock(account, nil);
    }];
}

- (void)logout
{
    NSString *emailAddress = self.emailAddress;
    
    [UICKeyChainStore removeAllItemsForService:self.serviceIdentifier];
    
    [self.keyChainStore setString:emailAddress forKey:ServiceIdentifierEmailStoreKey];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RTSIdentityServiceUserLoggedOutNotification
                                                        object:self
                                                      userInfo:@{ RTSIdentityServiceEmailAddressKey : emailAddress ?: NSNull.null }];
}

#pragma mark Private

- (void)loggedWithSessionToken:(NSString *)sessionToken
{
    [self.keyChainStore setString:sessionToken forKey:ServiceIdentifierSessionTokenStoreKey];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *emailAddress = self.emailAddress;
        [[NSNotificationCenter defaultCenter] postNotificationName:RTSIdentityServiceUserLoggedInNotification
                                                            object:self
                                                          userInfo:@{ RTSIdentityServiceEmailAddressKey : emailAddress ?: NSNull.null }];
    });
    
    self.profileSessionTask = [self accountWithCompletionBlock:^(RTSAccount * _Nullable account, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *emailAddress = self.emailAddress;
            [[NSNotificationCenter defaultCenter] postNotificationName:RTSIdentityServiceUserMetadatasUpdateNotification
                                                                object:self
                                                              userInfo:@{ RTSIdentityServiceEmailAddressKey : emailAddress ?: NSNull.null }];
        });
    }];
    [self.profileSessionTask resume];
}

@end
