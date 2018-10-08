//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityService.h"

#import "NSBundle+SRGIdentity.h"
#import "SRGIdentityLogger.h"
#import "UIWindow+SRGIdentity.h"

#import <AuthenticationServices/AuthenticationServices.h>
#import <FXReachability/FXReachability.h>
#import <libextobjc/libextobjc.h>
#import <SafariServices/SafariServices.h>
#import <SRGNetwork/SRGNetwork.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import <UIKit/UIKit.h>

static SRGIdentityService *s_currentIdentityService;

NSString * const SRGIdentityServiceUserDidLoginNotification = @"SRGIdentityServiceUserDidLoginNotification";
NSString * const SRGIdentityServiceUserDidLogoutNotification = @"SRGIdentityServiceUserDidLogoutNotification";
NSString * const SRGIdentityServiceDidUpdateAccountNotification = @"SRGIdentityServiceDidUpdateAccountNotification";

NSString * const SRGIdentityServiceAccountKey = @"SRGIdentityServiceAccount";

static NSString * SRGServiceIdentifierEmailStoreKey;
static NSString * SRGServiceIdentifierSessionTokenStoreKey;

__attribute__((constructor)) static void SRGIdentityServiceInit(void)
{
    SRGServiceIdentifierEmailStoreKey = [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".email"];
    SRGServiceIdentifierSessionTokenStoreKey = [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".sessionToken"];
}

@interface SRGIdentityService ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) UICKeyChainStore *keyChainStore;

@property (nonatomic, readonly) NSString *serviceIdentifier;

@property (nonatomic) SRGAccount *account;

@property (nonatomic) id authenticationSession          /* Must be strong to avoid cancellation. Contains ASWebAuthenticationSession or SFAuthenticationSession (have compatible APIs) */;

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
            SRGIdentityLogError(@"service", @"No URL scheme declared in your application Info.plist file under the "
                                "'CFBundleURLTypes' key. The application must at least contain one item with one scheme "
                                "to allow a correct authentication workflow.");
        }
    });
    return URLScheme;
}

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        UICKeyChainStoreProtocolType keyChainStoreProtocolType = ([serviceURL.scheme.lowercaseString isEqualToString:@"https"]) ? UICKeyChainStoreProtocolTypeHTTP : UICKeyChainStoreProtocolTypeHTTPS;
        self.keyChainStore = [UICKeyChainStore keyChainStoreWithServer:serviceURL protocolType:keyChainStoreProtocolType];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(reachabilityDidChange:)
                                                   name:FXReachabilityStatusDidChangeNotification
                                                 object:nil];
        
        [self updateAccount];
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithServiceURL:[NSURL new]];
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

#pragma mark URLs

- (NSURL *)loginRedirectURL
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.serviceURL resolvingAgainstBaseURL:YES];
    URLComponents.scheme = [SRGIdentityService applicationURLScheme];
    return URLComponents.URL;
}

- (NSURL *)loginRequestURLWithEmailAddress:(NSString *)emailAddress
{
    NSURL *requestURL = [NSURL URLWithString:@"responsive/login" relativeToURL:self.serviceURL];
    NSURL *redirectURL = [self loginRedirectURL];
    
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

- (BOOL)shouldHandleCallbackURL:(NSURL *)URL
{
    NSURL *standardizedURL = URL.standardizedURL;
    NSURL *standardizedRedirectURL = [self loginRedirectURL].standardizedURL;
    
    return ((standardizedURL.scheme == standardizedRedirectURL.scheme) || [standardizedURL.scheme isEqualToString:standardizedRedirectURL.scheme])
        && ((standardizedURL.host == standardizedRedirectURL.host) || [standardizedURL.host isEqualToString:standardizedRedirectURL.host])
        && ((standardizedURL.port == standardizedRedirectURL.port) || [standardizedURL.port isEqual:standardizedRedirectURL.port])
        && ((standardizedURL.path == standardizedRedirectURL.path) || [standardizedURL.path isEqual:standardizedRedirectURL.path]);
}

- (NSString *)tokenFromURL:(NSURL *)URL
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"token"];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    return queryItem.value;
}

#pragma mark Login / logout

// TODO: Prevent concurrent login attempts, or cancel previous one. Also prevent or govern interactions with logout.
//       Define behavior when user already logged in.
- (BOOL)loginWithEmailAddress:(NSString *)emailAddress
{
    @weakify(self)
    void (^completionHandler)(NSURL * _Nullable, NSError * _Nullable) = ^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
        @strongify(self)
        [self handleCallbackURL:callbackURL];
    };
    
    NSURL *requestURL = [self loginRequestURLWithEmailAddress:emailAddress];
    
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
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:requestURL];
        UIViewController *presentingViewController = UIApplication.sharedApplication.keyWindow.srgidentity_topViewController;
        [presentingViewController presentViewController:safariViewController animated:YES completion:nil];
    }
    
    return YES;
}

- (void)logout
{
    if (! self.sessionToken) {
        return;
    }
    
    NSURL *URL = [NSURL URLWithString:@"api/v2/session/logout" relativeToURL:self.serviceURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"DELETE";
    
    NSString *sessionToken = [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey];
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    [[[SRGNetworkRequest alloc] initWithURLRequest:request session:NSURLSession.sharedSession options:0 completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // Remove local login informations in any cases.
        dispatch_async(dispatch_get_main_queue(), ^{
            SRGAccount *account = self.account;
            
            [self.keyChainStore removeItemForKey:SRGServiceIdentifierEmailStoreKey];
            [self.keyChainStore removeItemForKey:SRGServiceIdentifierSessionTokenStoreKey];
            self.account = nil;
            
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[SRGIdentityServiceAccountKey] = account;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                                object:self
                                                              userInfo:[userInfo copy]];
        });
    }] resume];
}

#pragma mark Callback URL handling

- (BOOL)handleCallbackURL:(NSURL *)callbackURL
{
    if (! [self shouldHandleCallbackURL:callbackURL]) {
        return NO;
    }
    
    NSString *token = [self tokenFromURL:callbackURL];
    if (! token) {
        return YES;
    }
    
    [self.keyChainStore setString:token forKey:SRGServiceIdentifierSessionTokenStoreKey];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLoginNotification
                                                        object:self
                                                      userInfo:nil];
    [self updateAccount];
    
    if (self.authenticationSession) {
        self.authenticationSession = nil;
    }
    else {
        UIViewController *presentingViewController = UIApplication.sharedApplication.keyWindow.srgidentity_topViewController;
        [presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
    
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
        
        [self.keyChainStore setString:account.emailAddress forKey:SRGServiceIdentifierEmailStoreKey];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.account = account;
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceDidUpdateAccountNotification
                                                                object:self
                                                              userInfo:@{ SRGIdentityServiceAccountKey : account }];
        });
    }] resume];
}

#pragma mark Notifications

- (void)reachabilityDidChange:(NSNotification *)notification
{
    if ([FXReachability sharedInstance].reachable) {
        [self updateAccount];
    }
}

@end
