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
static BOOL s_loggingIn;

NSString * const SRGIdentityServiceUserDidLoginNotification = @"SRGIdentityServiceUserDidLoginNotification";
NSString * const SRGIdentityServiceUserDidCancelLoginNotification = @"SRGIdentityServiceUserDidCancelLoginNotification";
NSString * const SRGIdentityServiceUserDidLogoutNotification = @"SRGIdentityServiceUserDidLogoutNotification";
NSString * const SRGIdentityServiceDidUpdateAccountNotification = @"SRGIdentityServiceDidUpdateAccountNotification";

NSString * const SRGIdentityServiceAccountKey = @"SRGIdentityServiceAccount";
NSString * const SRGIdentityServicePreviousAccountKey = @"SRGIdentityServicePreviousAccountKey";

static NSString *SRGServiceIdentifierEmailStoreKey(void)
{
    return [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".email"];
}

static NSString *SRGServiceIdentifierSessionTokenStoreKey(void)
{
    return [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".sessionToken"];
}

@interface SRGIdentityService () <SFSafariViewControllerDelegate>

@property (nonatomic) NSURL *providerURL;
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

- (instancetype)initWithProviderURL:(NSURL *)providerURL
{
    if (self = [super init]) {
        self.providerURL = providerURL;
        UICKeyChainStoreProtocolType keyChainStoreProtocolType = [providerURL.scheme.lowercaseString isEqualToString:@"https"] ? UICKeyChainStoreProtocolTypeHTTPS : UICKeyChainStoreProtocolTypeHTTP;
        self.keyChainStore = [UICKeyChainStore keyChainStoreWithServer:providerURL protocolType:keyChainStoreProtocolType];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(reachabilityDidChange:)
                                                   name:FXReachabilityStatusDidChangeNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationWillEnterForeground:)
                                                   name:UIApplicationWillEnterForegroundNotification
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
    return [self initWithProviderURL:[NSURL new]];
}

#pragma clang diagnostic pop

#pragma mark Getters and setters

- (BOOL)isLoggedIn
{
    return (self.sessionToken != nil);
}

- (NSString *)sessionToken
{
    return [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey()];
}

- (NSString *)emailAddress
{
    return [self.keyChainStore stringForKey:SRGServiceIdentifierEmailStoreKey()];
}

- (void)setAccount:(SRGAccount *)account
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[SRGIdentityServicePreviousAccountKey] = _account;

    _account = account;
    
    userInfo[SRGIdentityServiceAccountKey] = account;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceDidUpdateAccountNotification
                                                        object:self
                                                      userInfo:[userInfo copy]];
}

#pragma mark URLs

- (NSURL *)loginRedirectURL
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.providerURL resolvingAgainstBaseURL:YES];
    URLComponents.scheme = [SRGIdentityService applicationURLScheme];
    return URLComponents.URL;
}

- (NSURL *)loginRequestURLWithEmailAddress:(NSString *)emailAddress
{
    NSURL *requestURL = [NSURL URLWithString:@"login" relativeToURL:self.providerURL];
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

- (BOOL)loginWithEmailAddress:(NSString *)emailAddress
{
    if (s_loggingIn || self.loggedIn) {
        return NO;
    }
    
    @weakify(self)
    void (^completionHandler)(NSURL * _Nullable, NSError * _Nullable) = ^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
        void (^notifyCancel)(void) = ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidCancelLoginNotification
                                                                object:self
                                                              userInfo:nil];
        };
        
        @strongify(self)
        if (callbackURL) {
            [self handleCallbackURL:callbackURL];
        }
        else if (@available(iOS 12.0, *)) {
            if ([error.domain isEqualToString:ASWebAuthenticationSessionErrorDomain] && error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin) {
                notifyCancel();
            }
        }
        else if (@available(iOS 11.0, *)) {
            if ([error.domain isEqualToString:SFAuthenticationErrorDomain] && error.code == SFAuthenticationErrorCanceledLogin) {
                notifyCancel();
            }
        }
        s_loggingIn = NO;
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
        safariViewController.delegate = self;
        UIViewController *presentingViewController = UIApplication.sharedApplication.keyWindow.srgidentity_topViewController;
        [presentingViewController presentViewController:safariViewController animated:YES completion:nil];
    }
    
    s_loggingIn = YES;
    return YES;
}

- (BOOL)logout
{
    if (s_loggingIn || ! self.sessionToken ) {
        return NO;
    }
    
    NSURL *URL = [NSURL URLWithString:@"api/v2/session/logout" relativeToURL:self.providerURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"DELETE";
    
    NSString *sessionToken = [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey()];
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    [[[SRGNetworkRequest alloc] initWithURLRequest:request session:NSURLSession.sharedSession options:0 completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // Ignore errors and cleanup local credentials in all cases.
        [self.keyChainStore removeItemForKey:SRGServiceIdentifierEmailStoreKey()];
        [self.keyChainStore removeItemForKey:SRGServiceIdentifierSessionTokenStoreKey()];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.account = nil;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                                object:self
                                                              userInfo:nil];
        });
    }] resume];
    
    return YES;
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
    
    [self.keyChainStore setString:token forKey:SRGServiceIdentifierSessionTokenStoreKey()];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLoginNotification
                                                        object:self
                                                      userInfo:nil];
    [self updateAccount];
    
    if (self.authenticationSession) {
        self.authenticationSession = nil;
    }
    else {
        UIViewController *presentingViewController = UIApplication.sharedApplication.keyWindow.srgidentity_topViewController;
        [presentingViewController dismissViewControllerAnimated:YES completion:^{
            s_loggingIn = NO;
        }];
    }
    
    return YES;
}

#pragma mark SFSafariViewControllerDelegate delegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidCancelLoginNotification
                                                        object:self
                                                      userInfo:nil];    
    s_loggingIn = NO;
}

#pragma mark Account information

- (void)updateAccount
{
    NSString *sessionToken = [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey()];
    if (! sessionToken) {
        return;
    }
    
    NSURL *URL = [NSURL URLWithString:@"api/v2/session/user/profile" relativeToURL:self.providerURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    [[[SRGNetworkRequest alloc] initWithJSONDictionaryURLRequest:request session:NSURLSession.sharedSession options:0 completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        NSDictionary *user = JSONDictionary[@"user"];
        SRGAccount *account = [MTLJSONAdapter modelOfClass:SRGAccount.class fromJSONDictionary:user error:NULL];
        if (! account) {
            return;
        }
        
        [self.keyChainStore setString:account.emailAddress forKey:SRGServiceIdentifierEmailStoreKey()];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.account = account;
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

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self updateAccount];
}

@end
