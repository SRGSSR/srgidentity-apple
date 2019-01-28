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
#import <objc/runtime.h>
#import <SafariServices/SafariServices.h>
#import <SRGNetwork/SRGNetwork.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import <UIKit/UIKit.h>

static SRGIdentityService *s_currentIdentityService;
static BOOL s_loggingIn;

static NSMutableDictionary<NSString *, NSValue *> *s_identityServices;
static NSDictionary<NSValue *, NSValue *> *s_originalImplementations;

NSString * const SRGIdentityServiceUserDidLoginNotification = @"SRGIdentityServiceUserDidLoginNotification";
NSString * const SRGIdentityServiceUserDidCancelLoginNotification = @"SRGIdentityServiceUserDidCancelLoginNotification";
NSString * const SRGIdentityServiceUserDidLogoutNotification = @"SRGIdentityServiceUserDidLogoutNotification";
NSString * const SRGIdentityServiceDidUpdateAccountNotification = @"SRGIdentityServiceDidUpdateAccountNotification";

NSString * const SRGIdentityServiceAccountKey = @"SRGIdentityServiceAccount";
NSString * const SRGIdentityServicePreviousAccountKey = @"SRGIdentityServicePreviousAccount";

NSString * const SRGIdentityServiceUnauthorizedKey = @"SRGIdentityServiceUnauthorized";
NSString * const SRGIdentityServiceDeletedKey = @"SRGIdentityServiceDeletedKey";

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

static BOOL swizzled_application_openURL_options(id self, SEL _cmd, UIApplication *application, NSURL *URL, NSDictionary<UIApplicationOpenURLOptionsKey,id> *options);

@interface NSObject (SRGIdentityApplicationDelegateHooks)

- (BOOL)srg_default_application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

@end

@interface SRGIdentityService () <SFSafariViewControllerDelegate>

@property (nonatomic, copy) NSString *identifier;

@property (nonatomic) NSURL *webserviceURL;
@property (nonatomic) NSURL *websiteURL;

@property (nonatomic) UICKeyChainStore *keyChainStore;

@property (nonatomic) id authenticationSession          /* Must be strong to avoid cancellation. Contains ASWebAuthenticationSession or SFAuthenticationSession (have compatible APIs) */;

@property (nonatomic) SRGNetworkRequest *accountUpdateRequest;
@property (nonatomic, copy) void (^dismissal)(void);

@end

__attribute__((constructor)) static void SRGIdentityServiceInit(void)
{
    if (@available(iOS 11.0, *)) {
        return;
    }
    
    NSMutableDictionary<NSValue *, NSValue *> *originalImplementations = [NSMutableDictionary dictionary];
    
    // The `-application:openURL:options:` application delegate method must be available at the time the application is
    // instantiated, see https://stackoverflow.com/questions/14696078/runtime-added-applicationopenurl-not-fires.
    unsigned int numberOfClasses = 0;
    Class *classList = objc_copyClassList(&numberOfClasses);
    for (unsigned int i = 0; i < numberOfClasses; ++i) {
        Class cls = classList[i];
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
    
    s_originalImplementations = [originalImplementations copy];
}

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

- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL
{
    if (self = [super init]) {
        self.identifier = NSUUID.UUID.UUIDString;
        
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            s_identityServices = [NSMutableDictionary dictionary];
        });
        s_identityServices[self.identifier] = [NSValue valueWithNonretainedObject:self];
        
        self.webserviceURL = webserviceURL;
        self.websiteURL = websiteURL;
        
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

- (void)dealloc
{
    s_identityServices[self.identifier] = nil;
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
    return accountData ? [NSKeyedUnarchiver unarchiveObjectWithData:accountData] : nil;
}

- (void)setAccount:(SRGAccount *)account
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[SRGIdentityServicePreviousAccountKey] = self.account;
    
    NSData *accountData = account ? [NSKeyedArchiver archivedDataWithRootObject:account] : nil;
    [self.keyChainStore setData:accountData forKey:SRGServiceIdentifierAccountStoreKey()];
    
    userInfo[SRGIdentityServiceAccountKey] = account;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceDidUpdateAccountNotification
                                                        object:self
                                                      userInfo:[userInfo copy]];
}

- (NSString *)sessionToken
{
    return [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey()];
}

- (void)setSessionToken:(NSString *)sessionToken
{
    [self.keyChainStore setString:sessionToken forKey:SRGServiceIdentifierSessionTokenStoreKey()];
}

#pragma mark URL handling

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
    if (s_loggingIn) {
        return NO;
    }
    
    [self.accountUpdateRequest cancel];
    
    NSString *sessionToken = self.sessionToken;
    if (! sessionToken) {
        return NO;
    }
    
    [self cleanup];
    [self dismissAccountView];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                        object:self
                                                      userInfo:nil];
    
    NSURL *URL = [self.webserviceURL URLByAppendingPathComponent:@"v1/logout"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"DELETE";
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    [[[SRGNetworkRequest alloc] initWithURLRequest:request session:NSURLSession.sharedSession options:0 completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            SRGIdentityLogInfo(@"service", @"The logout request failed with error %@", error);
        }
    }] resume];
    
    return YES;
}

- (void)cleanup
{
    self.emailAddress = nil;
    self.sessionToken = nil;
    self.account = nil;
}

#pragma mark Account information

- (void)updateAccount
{
    if (self.accountUpdateRequest) {
        return;
    }
    
    NSString *sessionToken = [self.keyChainStore stringForKey:SRGServiceIdentifierSessionTokenStoreKey()];
    if (! sessionToken) {
        return;
    }
    
    NSURL *URL = [self.webserviceURL URLByAppendingPathComponent:@"v1/userinfo"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    self.accountUpdateRequest = [[SRGNetworkRequest alloc] initWithJSONDictionaryURLRequest:request session:NSURLSession.sharedSession options:0 completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        self.accountUpdateRequest = nil;
        
        if (error) {
            SRGIdentityLogInfo(@"service", @"Account update failed with error %@", error);
            
            if ([error.domain isEqualToString:SRGNetworkErrorDomain] && error.code == SRGNetworkErrorHTTP && [error.userInfo[SRGNetworkHTTPStatusCodeKey] integerValue] == 401) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self cleanup];
                    [self dismissAccountView];
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityServiceUserDidLogoutNotification
                                                                        object:self
                                                                      userInfo:@{ SRGIdentityServiceUnauthorizedKey : @YES }];
                });
            }
            return;
        }
        
        SRGAccount *account = [MTLJSONAdapter modelOfClass:SRGAccount.class fromJSONDictionary:JSONDictionary error:NULL];
        if (! account) {
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.emailAddress = account.emailAddress;
            self.account = account;
        });
    }];
    [self.accountUpdateRequest resume];
}

#pragma mark Account request

- (void)showAccountViewWithPresentation:(void (^)(NSURLRequest * _Nonnull, SRGIdentityNavigationAction (^ _Nonnull)(NSURL * _Nonnull)))presentation
                              dismissal:(void (^)(void))dismissal
{
    NSURLRequest *request = [self accountRequest];
    if (! request) {
        return;
    }
    
    if (self.dismissal) {
        return;
    }
    
    self.dismissal = dismissal;
    
    SRGIdentityNavigationAction (^URLHandler)(NSURL *) = ^(NSURL *URL) {
        return [self handleCallbackURL:URL] ? SRGIdentityNavigationActionCancel : SRGIdentityNavigationActionAllow;
    };
    
    presentation(request, URLHandler);
}

- (void)hideAccountView
{
    [self dismissAccountView];
    [self updateAccount];
}

- (void)dismissAccountView
{
    self.dismissal ? self.dismissal() : nil;
    self.dismissal = nil;
}

- (NSURLRequest *)accountRequest
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
    return [request copy];
}

#pragma mark Unauthorization reporting

- (void)reportUnauthorization
{
    [self updateAccount];
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
        [self.accountUpdateRequest cancel];
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
        [self.accountUpdateRequest cancel];
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
        [self.accountUpdateRequest cancel];
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
            UIViewController *presentingViewController = UIApplication.sharedApplication.keyWindow.srgidentity_topViewController;
            [presentingViewController dismissViewControllerAnimated:YES completion:^{
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
            [self class],
            self,
            self.keyChainStore];
}

@end

@implementation NSObject (SRGIdentityApplicationDelegateHooks)

- (BOOL)srg_default_application:(UIApplication *)application openURL:(NSURL *)URL options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return NO;
}

@end

static BOOL swizzled_application_openURL_options(id self, SEL _cmd, UIApplication *application, NSURL *URL, NSDictionary<UIApplicationOpenURLOptionsKey,id> *options)
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:YES];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), SRGIdentityServiceQueryItemName];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    if (queryItem.value) {
        SRGIdentityService *identityService = [s_identityServices[queryItem.value] nonretainedObjectValue];
        if ([identityService handleCallbackURL:URL]) {
            return YES;
        }
    }
    
    // Use -class method to be compatible with dynamic subclassing if KVO registrations are made for self
    // (object_getClass would return the KVO subclass, while -class returns a proper lie about the true class)
    NSValue *key = [NSValue valueWithNonretainedObject:[self class]];
    BOOL (*originalImplementation)(id, SEL, id, id, id) = [s_originalImplementations[key] pointerValue];
    return originalImplementation(self, _cmd, application, URL, options);
}
