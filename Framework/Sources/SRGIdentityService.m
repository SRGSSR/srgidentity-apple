//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityService.h"

#import "NSBundle+SRGIdentity.h"
#import "SRGIdentityLogger.h"
#import "SRGIdentityNavigationController.h"
#import "UIWindow+SRGIdentity.h"

#if TARGET_OS_TV
#import "SRGIdentityLoginViewController.h"
#else
#import "SRGIdentityWebViewController.h"
#endif

#import <AuthenticationServices/AuthenticationServices.h>
#import <FXReachability/FXReachability.h>
#import <libextobjc/libextobjc.h>
#import <objc/runtime.h>
#import <SRGNetwork/SRGNetwork.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import <UIKit/UIKit.h>

#if TARGET_OS_IOS
#import <SafariServices/SafariServices.h>
#endif

static SRGIdentityService *s_currentIdentityService;
static BOOL s_loggingIn;

static NSMapTable<NSString *, SRGIdentityService *> *s_identityServices;
static NSDictionary<NSValue *, NSValue *> *s_originalImplementations;

NSString * const SRGIdentityServiceUserDidLoginNotification = @"SRGIdentityServiceUserDidLoginNotification";
NSString * const SRGIdentityServiceUserDidCancelLoginNotification = @"SRGIdentityServiceUserDidCancelLoginNotification";
NSString * const SRGIdentityServiceUserDidLogoutNotification = @"SRGIdentityServiceUserDidLogoutNotification";
NSString * const SRGIdentityServiceDidUpdateAccountNotification = @"SRGIdentityServiceDidUpdateAccountNotification";

NSString * const SRGIdentityServiceAccountKey = @"SRGIdentityServiceAccount";
NSString * const SRGIdentityServicePreviousAccountKey = @"SRGIdentityServicePreviousAccount";

NSString * const SRGIdentityServiceUnauthorizedKey = @"SRGIdentityServiceUnauthorized";
NSString * const SRGIdentityServiceDeletedKey = @"SRGIdentityServiceDeleted";

static NSString * const SRGIdentityServiceQueryItemName = @"identity_service";

static NSString *SRGServiceIdentifierEmailStoreKey(void)
{
    return [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".email"];
}

static NSString *SRGServiceIdentifierSessionTokenStoreKey(void)
{
    return [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".sessionToken"];
}

static NSString *SRGServiceIdentifierAccountStoreKey(void)
{
    return [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".account"];
}

// TODO: Use secure unarchiving directly once iOS 11 is the minimum version
static SRGAccount *SRGIdentityAccountFromData(NSData *data)
{
    if (! data) {
        return nil;
    }
    
#if TARGET_OS_TV
    return [NSKeyedUnarchiver unarchivedObjectOfClass:SRGAccount.class fromData:data error:NULL];
#else
    if (@available(iOS 11, *)) {
        return [NSKeyedUnarchiver unarchivedObjectOfClass:SRGAccount.class fromData:data error:NULL];
    }
    else {
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
#endif
}

// TODO: Use secure archiving directly once iOS 11 is the minimum version
static NSData *SRGIdentityDataFromAccount(SRGAccount *account)
{
    if (! account) {
        return nil;
    }
    
#if TARGET_OS_TV
    return [NSKeyedArchiver archivedDataWithRootObject:account requiringSecureCoding:YES error:NULL];
#else
    if (@available(iOS 11, *)) {
        return [NSKeyedArchiver archivedDataWithRootObject:account requiringSecureCoding:YES error:NULL];
    }
    else {
        return [NSKeyedArchiver archivedDataWithRootObject:account];
    }
#endif
}

@interface SRGIdentityService ()
#if TARGET_OS_IOS
<SFSafariViewControllerDelegate>
#endif

@property (nonatomic, copy) NSString *identifier;

@property (nonatomic) NSURL *webserviceURL;
@property (nonatomic) NSURL *websiteURL;
@property (nonatomic) SRGIdentityLoginMethod loginMethod;

@property (nonatomic) UICKeyChainStore *keyChainStore;

@property (nonatomic) id authenticationSession          /* Must be strong to avoid cancellation. Contains ASWebAuthenticationSession or SFAuthenticationSession (have compatible APIs) */;

@property (nonatomic, weak) SRGRequest *accountRequest;
@property (nonatomic, weak) UIViewController *accountNavigationController;

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

- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL loginMethod:(SRGIdentityLoginMethod)loginMethod
{
    if (self = [super init]) {
        self.identifier = NSUUID.UUID.UUIDString;
        
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            s_identityServices = [NSMapTable mapTableWithKeyOptions:NSHashTableStrongMemory
                                                       valueOptions:NSHashTableWeakMemory];
        });
        [s_identityServices setObject:self forKey:self.identifier];
        
        self.webserviceURL = webserviceURL;
        self.websiteURL = websiteURL;
        self.loginMethod = loginMethod;
        
        UICKeyChainStoreProtocolType keyChainStoreProtocolType = [websiteURL.scheme.lowercaseString isEqualToString:@"https"] ? UICKeyChainStoreProtocolTypeHTTPS : UICKeyChainStoreProtocolTypeHTTP;
        self.keyChainStore = [UICKeyChainStore keyChainStoreWithServer:websiteURL protocolType:keyChainStoreProtocolType];
        
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

- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL
{
    return [self initWithWebserviceURL:webserviceURL websiteURL:websiteURL loginMethod:SRGIdentityLoginMethodDefault];
}

- (void)dealloc
{
    [s_identityServices removeObjectForKey:self.identifier];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithWebserviceURL:[NSURL new] websiteURL:[NSURL new]];
}

#pragma clang diagnostic pop

#pragma mark Getters and setters

- (BOOL)isLoggedIn
{
    return (self.sessionToken != nil);
}

- (NSString *)emailAddress
{
    return [self.keyChainStore stringForKey:SRGServiceIdentifierEmailStoreKey()];
}

- (void)setEmailAddress:(NSString *)emailAddress
{
    [self.keyChainStore setString:emailAddress forKey:SRGServiceIdentifierEmailStoreKey()];
}

- (SRGAccount *)account
{
    NSData *accountData = [self.keyChainStore dataForKey:SRGServiceIdentifierAccountStoreKey()];
    return SRGIdentityAccountFromData(accountData);
}

- (void)setAccount:(SRGAccount *)account
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[SRGIdentityServicePreviousAccountKey] = self.account;
    
    NSData *accountData = SRGIdentityDataFromAccount(account);
    [self.keyChainStore setData:accountData forKey:SRGServiceIdentifierAccountStoreKey()];
    
    userInfo[SRGIdentityServiceAccountKey] = account;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceDidUpdateAccountNotification
                                                        object:self
                                                      userInfo:userInfo.copy];
}

- (NSString *)sessionToken
{
    return [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey()];
}

- (void)setSessionToken:(NSString *)sessionToken
{
    [self.keyChainStore setString:sessionToken forKey:SRGServiceIdentifierSessionTokenStoreKey()];
}

#pragma mark Login / logout

- (BOOL)loginWithEmailAddress:(NSString *)emailAddress
{
    if (s_loggingIn || self.loggedIn) {
        return NO;
    }
 
#if TARGET_OS_IOS
    @weakify(self)
    void (^completionHandler)(NSURL * _Nullable, NSError * _Nullable) = ^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
        void (^notifyCancel)(void) = ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidCancelLoginNotification
                                                                object:self
                                                              userInfo:nil];
        };
        
        s_loggingIn = NO;
        
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
    };
    
    NSURL *requestURL = [self loginRequestURLWithEmailAddress:emailAddress];
    
    void (^loginWithSafari)(void) = ^{
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:requestURL];
        safariViewController.delegate = self;
        UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.srgidentity_topViewController;
        [topViewController presentViewController:safariViewController animated:YES completion:nil];
    };
    
    if (self.loginMethod == SRGIdentityLoginMethodAuthenticationSession) {
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
            loginWithSafari();
        }
    }
    else {
        loginWithSafari();
    }
#else
    UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.srgidentity_topViewController;
    SRGIdentityLoginViewController *loginViewController = [[SRGIdentityLoginViewController alloc] initWithWebserviceURL:self.webserviceURL websiteURL:self.websiteURL emailAddress:emailAddress tokenBlock:^(NSString * _Nonnull sessionToken) {
        [topViewController dismissViewControllerAnimated:YES completion:nil];
        [self handleSessionToken:sessionToken];
    } dismissalBlock:^{
        s_loggingIn = NO;
    }];
    [topViewController presentViewController:loginViewController animated:YES completion:nil];
#endif
    
    s_loggingIn = YES;
    return YES;
}

- (BOOL)logout
{
    if (s_loggingIn) {
        return NO;
    }
    
    [self.accountRequest cancel];
    
    NSString *sessionToken = self.sessionToken;
    if (! sessionToken) {
        return NO;
    }
    
    [self cleanup];
    
#if TARGET_OS_IOS
    [self dismissAccountView];
#endif
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                        object:self
                                                      userInfo:nil];
    
    NSURL *URL = [self.webserviceURL URLByAppendingPathComponent:@"v1/logout"];
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"DELETE";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    [[SRGRequest dataRequestWithURLRequest:URLRequest session:NSURLSession.sharedSession completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            SRGIdentityLogInfo(@"service", @"The logout request failed with error %@", error);
        }
    }] resume];
    
    return YES;
}

- (void)cleanup
{
    [self.accountRequest cancel];
    self.emailAddress = nil;
    self.sessionToken = nil;
    self.account = nil;
}

#pragma mark Account information

- (void)updateAccount
{
    if (self.accountRequest.running) {
        return;
    }
    
    NSString *sessionToken = [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey()];
    if (! sessionToken) {
        return;
    }
    
    NSURL *URL = [self.webserviceURL URLByAppendingPathComponent:@"v1/userinfo"];
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    SRGRequest *accountRequest = [SRGRequest objectRequestWithURLRequest:URLRequest session:NSURLSession.sharedSession parser:^id _Nullable(NSData * _Nonnull data, NSError * _Nullable __autoreleasing * _Nullable pError) {
        NSDictionary *JSONDictionary = SRGNetworkJSONDictionaryParser(data, pError);
        if (! JSONDictionary) {
            return nil;
        }
        
        return [MTLJSONAdapter modelOfClass:SRGAccount.class fromJSONDictionary:JSONDictionary error:pError];
    } completionBlock:^(SRGAccount * _Nullable account, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            SRGIdentityLogInfo(@"service", @"Account update failed with error %@", error);
            
            if ([error.domain isEqualToString:SRGNetworkErrorDomain] && error.code == SRGNetworkErrorHTTP && [error.userInfo[SRGNetworkHTTPStatusCodeKey] integerValue] == 401) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self cleanup];
                    
#if TARGET_OS_IOS
                    [self dismissAccountView];
#endif
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                                        object:self
                                                                      userInfo:@{ SRGIdentityServiceUnauthorizedKey : @YES }];
                });
            }
            return;
        }
        
        if (! account) {
            return;
        }
        
        self.emailAddress = account.emailAddress;
        self.account = account;
    }];
    [accountRequest resume];
    self.accountRequest = accountRequest;
}

#pragma mark Unauthorization reporting

- (void)reportUnauthorization
{
    [self updateAccount];
}

#if TARGET_OS_IOS

#pragma mark URL handling

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

- (NSURL *)redirectURL
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.webserviceURL resolvingAgainstBaseURL:NO];
    URLComponents.scheme = [SRGIdentityService applicationURLScheme];
    URLComponents.queryItems = @[ [[NSURLQueryItem alloc] initWithName:SRGIdentityServiceQueryItemName value:self.identifier] ];
    return URLComponents.URL;
}

- (NSURL *)loginRequestURLWithEmailAddress:(NSString *)emailAddress
{
    NSURL *redirectURL = [self redirectURL];
    
    NSURL *URL = [self.websiteURL URLByAppendingPathComponent:@"login"];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSArray<NSURLQueryItem *> *queryItems = @[ [[NSURLQueryItem alloc] initWithName:@"redirect" value:redirectURL.absoluteString] ];
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
    NSURL *standardizedRedirectURL = [self redirectURL].standardizedURL;
    
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:YES];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), SRGIdentityServiceQueryItemName];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    
    return [standardizedURL.scheme isEqualToString:standardizedRedirectURL.scheme]
        && [standardizedURL.host isEqualToString:standardizedRedirectURL.host]
        && [standardizedURL.path isEqual:standardizedRedirectURL.path]
        && [self.identifier isEqualToString:queryItem.value];
}

- (NSString *)queryItemValueFromURL:(NSURL *)URL withName:(NSString *)queryName
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), queryName];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    return queryItem.value;
}

#pragma mark Account view

- (void)showAccountView
{
    NSAssert(NSThread.isMainThread, @"Must be called from the main thread");
    
    NSURLRequest *URLRequest = [self accountPresentationRequest];
    if (! URLRequest) {
        return;
    }
    
    if (self.accountNavigationController) {
        return;
    }
    
    SRGIdentityWebViewController *accountViewController = [[SRGIdentityWebViewController alloc] initWithRequest:URLRequest decisionHandler:^WKNavigationActionPolicy(NSURL * _Nonnull URL) {
        return [self handleCallbackURL:URL] ? WKNavigationActionPolicyCancel : WKNavigationActionPolicyAllow;
    }];
    accountViewController.title = SRGIdentityLocalizedString(@"My account", @"Title displayed at the top of the account view");
    accountViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:SRGIdentityLocalizedString(@"Close", @"Close button title")
                                                                                              style:UIBarButtonItemStyleDone
                                                                                             target:self
                                                                                             action:@selector(dismissAccountView:)];
    SRGIdentityNavigationController *accountNavigationController = [[SRGIdentityNavigationController alloc] initWithRootViewController:accountViewController];
    accountNavigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.srgidentity_topViewController;
    [topViewController presentViewController:accountNavigationController animated:YES completion:nil];
    
    self.accountNavigationController = accountNavigationController;
}

- (void)dismissAccountView
{
    if (! self.accountNavigationController) {
        return;
    }
    
    [self updateAccount];
    [self.accountNavigationController dismissViewControllerAnimated:YES completion:nil];
}

- (NSURLRequest *)accountPresentationRequest
{
    if (! self.sessionToken) {
        return nil;
    }
    
    NSURL *redirectURL = [self redirectURL];
    
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.websiteURL resolvingAgainstBaseURL:NO];
    NSArray<NSURLQueryItem *> *queryItems = @[ [[NSURLQueryItem alloc] initWithName:@"redirect" value:redirectURL.absoluteString] ];
    URLComponents.queryItems = queryItems;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URLComponents.URL];
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", self.sessionToken] forHTTPHeaderField:@"Authorization"];
    return request.copy;
}

- (void)dismissAccountView:(id)sender
{
    [self dismissAccountView];
}

#pragma mark Callback URL handling

- (BOOL)handleCallbackURL:(NSURL *)callbackURL
{
    if (! [self shouldHandleCallbackURL:callbackURL]) {
        return NO;
    }
    
    BOOL wasLoggedIn = self.loggedIn;
    
    NSString *action = [self queryItemValueFromURL:callbackURL withName:@"action"];
    if ([action isEqualToString:@"unauthorized"]) {
        [self.accountRequest cancel];
        [self cleanup];
        [self dismissAccountView];
        
        if (wasLoggedIn) {
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                                object:self
                                                              userInfo:@{ SRGIdentityServiceUnauthorizedKey : @YES }];
        }
        return YES;
    }
    else if ([action isEqualToString:@"log_out"]) {
        [self.accountRequest cancel];
        [self cleanup];
        [self dismissAccountView];
        
        if (wasLoggedIn) {
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                                object:self
                                                              userInfo:nil];
        }
        return YES;
    }
    else if ([action isEqualToString:@"account_deleted"]) {
        [self.accountRequest cancel];
        [self cleanup];
        [self dismissAccountView];
        
        if (wasLoggedIn) {
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                                object:self
                                                              userInfo:@{ SRGIdentityServiceDeletedKey : @YES }];
        }
        return YES;
    }
    
    NSString *sessionToken = [self queryItemValueFromURL:callbackURL withName:@"token"];
    if (sessionToken) {
        self.sessionToken = sessionToken;
        
        if (! wasLoggedIn) {
            [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLoginNotification
                                                                object:self
                                                              userInfo:nil];
        }
        [self updateAccount];
        
        if (self.authenticationSession) {
            self.authenticationSession = nil;
        }
        else {
            UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.srgidentity_topViewController;
            [topViewController dismissViewControllerAnimated:YES completion:^{
                s_loggingIn = NO;
            }];
        }
        return YES;
    }
    
    return NO;
}

#pragma mark SFSafariViewControllerDelegate delegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    s_loggingIn = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidCancelLoginNotification
                                                        object:self
                                                      userInfo:nil];
}

#else

#pragma mark Token handling

- (void)handleSessionToken:(NSString *)sessionToken
{
    self.sessionToken = sessionToken;
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLoginNotification
                                                        object:self
                                                      userInfo:nil];
    [self updateAccount];
}

#endif

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

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; keyChainStore = %@>",
            self.class,
            self,
            self.keyChainStore];
}

@end

#if TARGET_OS_IOS

static BOOL swizzled_application_openURL_options(id self, SEL _cmd, UIApplication *application, NSURL *URL, NSDictionary<UIApplicationOpenURLOptionsKey,id> *options);
static void swizzled_scene_openURLContexts(id self, SEL _cmd, UIScene *scene, NSSet<UIOpenURLContext *> *URLContexts) API_AVAILABLE(ios(13.0));

@interface NSObject (SRGIdentityApplicationDelegateHooks)

- (BOOL)srg_default_application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

@end

@interface NSObject (SRGIdentitySceneDelegateHooks)

- (void)srg_default_scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts API_AVAILABLE(ios(13.0));

@end

__attribute__((constructor)) static void SRGIdentityServiceInit(void)
{
    // A single map suffices. UISceneDelegate and UIApplicationDelegate URL handling are namely mutually exclusive (though
    // both can be used on iOS 13 depending on whether scenes are used or not).
    NSMutableDictionary<NSValue *, NSValue *> *originalImplementations = [NSMutableDictionary dictionary];
    
    // The `-application:openURL:options:` application delegate method must be available at the time the application is
    // instantiated, see https://stackoverflow.com/questions/14696078/runtime-added-applicationopenurl-not-fires.
    unsigned int numberOfClasses = 0;
    Class *classList = objc_copyClassList(&numberOfClasses);
    for (unsigned int i = 0; i < numberOfClasses; ++i) {
        Class cls = classList[i];
        
        if (@available(iOS 13, *)) {
            if (class_conformsToProtocol(cls, @protocol(UISceneDelegate))) {
                Method method = class_getInstanceMethod(cls, @selector(scene:openURLContexts:));
                if (! method) {
                    method = class_getInstanceMethod(cls, @selector(srg_default_scene:openURLContexts:));
                    class_addMethod(cls, @selector(scene:openURLContexts:), method_getImplementation(method), method_getTypeEncoding(method));
                }
                
                NSValue *key = [NSValue valueWithNonretainedObject:cls];
                originalImplementations[key] = [NSValue valueWithPointer:method_getImplementation(method)];
                
                class_replaceMethod(cls, @selector(scene:openURLContexts:), (IMP)swizzled_scene_openURLContexts, method_getTypeEncoding(method));
                continue;
            }
        }
        
        if (class_conformsToProtocol(cls, @protocol(UIApplicationDelegate))) {
            Method method = class_getInstanceMethod(cls, @selector(application:openURL:options:));
            if (! method) {
                method = class_getInstanceMethod(cls, @selector(srg_default_application:openURL:options:));
                class_addMethod(cls, @selector(application:openURL:options:), method_getImplementation(method), method_getTypeEncoding(method));
            }
            
            NSValue *key = [NSValue valueWithNonretainedObject:cls];
            originalImplementations[key] = [NSValue valueWithPointer:method_getImplementation(method)];
            
            class_replaceMethod(cls, @selector(application:openURL:options:), (IMP)swizzled_application_openURL_options, method_getTypeEncoding(method));
        }
    }
    free(classList);
    
    s_originalImplementations = originalImplementations.copy;
}

@implementation NSObject (SRGIdentityApplicationDelegateHooks)

- (BOOL)srg_default_application:(UIApplication *)application openURL:(NSURL *)URL options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return NO;
}

@end

@implementation NSObject (SRGIdentitySceneDelegateHooks)

- (void)srg_default_scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts API_AVAILABLE(ios(13.0))
{}

@end

static BOOL swizzled_application_openURL_options(id self, SEL _cmd, UIApplication *application, NSURL *URL, NSDictionary<UIApplicationOpenURLOptionsKey,id> *options)
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:YES];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), SRGIdentityServiceQueryItemName];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    if (queryItem.value) {
        SRGIdentityService *identityService = [s_identityServices objectForKey:queryItem.value];
        if ([identityService handleCallbackURL:URL]) {
            return YES;
        }
    }
    
    // Find a proper match along the class hierarchy. This also ensures correct behavior is the app delegate is dynamically
    // subclassed, either with a lie (e.g. KVO, for which self.class lies about the true class nature) or not.
    Class cls = object_getClass(self);
    while (cls != Nil) {
        NSValue *key = [NSValue valueWithNonretainedObject:cls];
        BOOL (*originalImplementation)(id, SEL, id, id, id) = [s_originalImplementations[key] pointerValue];
        if (originalImplementation) {
            return originalImplementation(self, _cmd, application, URL, options);
        }
        else {
            cls = class_getSuperclass(cls);
        }
    }
    
    SRGIdentityLogError(@"service", @"Could not call open URL app delegate original implementation for %@", self);
    return NO;
}

static void swizzled_scene_openURLContexts(id self, SEL _cmd, UIScene *scene, NSSet<UIOpenURLContext *> *URLContexts)
{
    for (UIOpenURLContext *URLContext in URLContexts) {
        NSURL *URL = URLContext.URL;
        NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:YES];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), SRGIdentityServiceQueryItemName];
        NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
        if (queryItem.value) {
            SRGIdentityService *identityService = [s_identityServices objectForKey:queryItem.value];
            if ([identityService handleCallbackURL:URL]) {
                return;
            }
        }
    }
    
    // Find a proper match along the class hierarchy. This also ensures correct behavior is the app delegate is dynamically
    // subclassed, either with a lie (e.g. KVO, for which self.class lies about the true class nature) or not.
    Class cls = object_getClass(self);
    while (cls != Nil) {
        NSValue *key = [NSValue valueWithNonretainedObject:cls];
        BOOL (*originalImplementation)(id, SEL, id, id) = [s_originalImplementations[key] pointerValue];
        if (originalImplementation) {
            originalImplementation(self, _cmd, scene, URLContexts);
            return;
        }
        else {
            cls = class_getSuperclass(cls);
        }
    }
}

#endif
