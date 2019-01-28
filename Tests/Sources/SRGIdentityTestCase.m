//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <libextobjc/libextobjc.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <SRGIdentity/SRGIdentity.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import <XCTest/XCTest.h>

static NSString *TestValidToken = @"0123456789";

NSString * const SRGIdentityTestShowAccountPresentationNotification = @"SRGIdentityTestShowAccountPresentationNotification";
NSString * const SRGIdentityTestDismissalAccountPresentationNotification = @"SRGIdentityTestDismissalAccountPresentationNotification";

@interface SRGIdentityService (Private)

- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@property (nonatomic, readonly, copy) NSString *identifier;

@end

static NSURL *TestWebserviceURL(void)
{
    return [NSURL URLWithString:@"https://api.srgssr.local"];
}

static NSURL *TestWebsiteURL(void)
{
    return [NSURL URLWithString:@"https://www.srgssr.local"];
}

static NSURL *TestLoginCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&token=%@", TestWebserviceURL().host, identityService.identifier, token];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestLogoutCallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&action=log_out", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestAccountDeletedCallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&action=account_deleted", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestUnauthorizedCallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&action=unauthorized", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestIgnored1CallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&action=unknown", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestIgnored2CallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"myapp://%@?identity_service=%@", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestIgnored3CallbackURL()
{
    NSString *URLString = [NSString stringWithFormat:@"https://www.srgssr.ch"];
    return [NSURL URLWithString:URLString];
}

@interface SRGIdentityTestCase : XCTestCase

@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic, weak) id<OHHTTPStubsDescriptor> loginRequestStub;

@end

@implementation SRGIdentityTestCase

#pragma mark Helpers

- (XCTestExpectation *)expectationForElapsedTimeInterval:(NSTimeInterval)timeInterval withHandler:(void (^)(void))handler
{
    XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"Wait for %@ seconds", @(timeInterval)]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
        handler ? handler() : nil;
    });
    return expectation;
}

#pragma mark Setup and teardown

- (void)setUp
{
    self.identityService = [[SRGIdentityService alloc] initWithWebserviceURL:TestWebserviceURL() websiteURL:TestWebsiteURL()];
    [self.identityService logout];
    
    self.loginRequestStub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqual:TestWebserviceURL().host];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        if ([request.URL.host isEqualToString:TestWebsiteURL().host]) {
            if ([request.URL.path containsString:@"login"]) {
                NSURLComponents *URLComponents = [[NSURLComponents alloc] initWithURL:request.URL resolvingAgainstBaseURL:NO];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"redirect"];
                NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
                
                NSURL *redirectURL = [NSURL URLWithString:queryItem.value];
                NSURLComponents *redirectURLComponents = [[NSURLComponents alloc] initWithURL:redirectURL resolvingAgainstBaseURL:NO];
                NSArray<NSURLQueryItem *> *queryItems = redirectURLComponents.queryItems ?: @[];
                queryItems = [queryItems arrayByAddingObject:[[NSURLQueryItem alloc] initWithName:@"token" value:@"0123456789"]];
                redirectURLComponents.queryItems = queryItems;
                
                return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                   statusCode:302
                                                      headers:@{ @"Location" : redirectURLComponents.URL.absoluteString }] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
            }
        }
        else if ([request.URL.host isEqualToString:TestWebserviceURL().host]) {
            if ([request.URL.path containsString:@"logout"]) {
                return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                   statusCode:204
                                                      headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
            }
            else if ([request.URL.path containsString:@"userinfo"]) {
                NSString *validAuthorizationHeader = [NSString stringWithFormat:@"sessionToken %@", @"0123456789"];
                if ([[request valueForHTTPHeaderField:@"Authorization"] isEqualToString:validAuthorizationHeader]) {
                    NSDictionary<NSString *, id> *account = @{ @"id" : @"1234",
                                                               @"publicUid" : @"4321",
                                                               @"login" : @"test@srgssr.ch",
                                                               @"displayName": @"Play SRG",
                                                               @"firstName": @"Play",
                                                               @"lastName": @"SRG",
                                                               @"gender": @"other",
                                                               @"birthdate": @"2001-01-01" };
                    return [[OHHTTPStubsResponse responseWithData:[NSJSONSerialization dataWithJSONObject:account options:0 error:NULL]
                                                       statusCode:200
                                                          headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
                else {
                    return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                       statusCode:401
                                                          headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
            }
        }
        
        // No match, return 404
        return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                           statusCode:404
                                              headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
    }];
    self.loginRequestStub.name = @"Login request";
}

- (void)tearDown
{
    [self.identityService logout];
    self.identityService = nil;
    
    [OHHTTPStubs removeStub:self.loginRequestStub];
}

#pragma mark Tests

- (void)testLoginHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertTrue(self.identityService.loggedIn);
}

- (void)testLogoutHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceUnauthorizedKey], @NO);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLogoutCallbackURL(self.identityService)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testAccountDeletedHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceUnauthorizedKey], @NO);
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceDeletedKey], @YES);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestAccountDeletedCallbackURL(self.identityService)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testUnauthorizedHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceUnauthorizedKey], @YES);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestUnauthorizedCallbackURL(self.identityService)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testIgnoredHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLogoutNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    BOOL hasHandledCallbackURL1 = [self.identityService handleCallbackURL:TestIgnored1CallbackURL(self.identityService)];
    XCTAssertFalse(hasHandledCallbackURL1);
    BOOL hasHandledCallbackURL2 = [self.identityService handleCallbackURL:TestIgnored2CallbackURL(self.identityService)];
    XCTAssertFalse(hasHandledCallbackURL2);
    BOOL hasHandledCallbackURL3 = [self.identityService handleCallbackURL:TestIgnored3CallbackURL()];
    XCTAssertFalse(hasHandledCallbackURL3);
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
}

- (void)testLogout
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceUnauthorizedKey], @NO);
        return YES;
    }];
    
    XCTAssertTrue([self.identityService logout]);
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertFalse([self.identityService logout]);
}

- (void)testAccountUpdate
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertNotNil(notification.userInfo[SRGIdentityServiceAccountKey]);
        XCTAssertNil(notification.userInfo[SRGIdentityServicePreviousAccountKey]);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNotNil(self.identityService.emailAddress);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    XCTAssertNotNil(self.identityService.account);
    
    XCTAssertTrue(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceUnauthorizedKey], @NO);
        return YES;
    }];
    [self expectationForNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertNil(notification.userInfo[SRGIdentityServiceAccountKey]);
        XCTAssertNotNil(notification.userInfo[SRGIdentityServicePreviousAccountKey]);
        return YES;
    }];
    
    XCTAssertTrue([self.identityService logout]);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testAutomaticLogoutWhenUnauthorized
{
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, @"invalid_token")];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, @"invalid_token");
    
    // Wait until account information is requested. The token is invalid, the user unauthorized and therefore logged out automatically
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceUnauthorizedKey], @YES);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testUnverifiedReportedUnauthorization
{
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLogoutNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    [self expectationForNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.identityService reportUnauthorization];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
}

- (void)testMultipleUnverifiedReportedUnauthorizations
{
    // A first account update is performed after login. Wait for it
    [self expectationForNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    __block NSInteger numberOfUpdates = 0;
    id accountUpdateObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        ++numberOfUpdates;
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    // Unverified reported unauthorizations lead to an account update. Expect at most 1
    [self.identityService reportUnauthorization];
    [self.identityService reportUnauthorization];
    [self.identityService reportUnauthorization];
    [self.identityService reportUnauthorization];
    [self.identityService reportUnauthorization];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:accountUpdateObserver];
    }];
    
    XCTAssertEqual(numberOfUpdates, 1);
}

- (void)testNotLoggedInReportedUnauthorization
{
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    id loginObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLoginNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No login is expected");
    }];
    id accountUpdateObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No account update is expected");
    }];
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLogoutNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    [self.identityService reportUnauthorization];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:loginObserver];
        [NSNotificationCenter.defaultCenter removeObserver:accountUpdateObserver];
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
    
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
}

- (void)testShowAccountViewWithPresentationNotLogged
{
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    id showObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityTestShowAccountPresentationNotification object:self queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No account presentation show call is expected.");
    }];
    id dismissalObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityTestDismissalAccountPresentationNotification object:self queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No account presentation dismissal call is expected.");
    }];
    
    [self.identityService showAccountViewWithPresentation:^(NSURLRequest * _Nonnull request, SRGIdentityNavigationAction (^ _Nonnull URLHandler)(NSURL * _Nonnull)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestShowAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    } dismissal:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestDismissalAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:showObserver];
        [NSNotificationCenter.defaultCenter removeObserver:dismissalObserver];
    }];
}

- (void)testShowAndHideAccountViewWithPresentationLogged
{
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityTestShowAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService showAccountViewWithPresentation:^(NSURLRequest * _Nonnull request, SRGIdentityNavigationAction (^ _Nonnull URLHandler)(NSURL * _Nonnull)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestShowAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    } dismissal:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestDismissalAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    [self expectationForNotification:SRGIdentityTestDismissalAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService hideAccountView];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
}

- (void)testCantShowTwiceAccountViewWithPresentationLogged
{
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityTestShowAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService showAccountViewWithPresentation:^(NSURLRequest * _Nonnull request, SRGIdentityNavigationAction (^ _Nonnull URLHandler)(NSURL * _Nonnull)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestShowAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    } dismissal:^{}];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    id showObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityTestShowAccountPresentationNotification object:self queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail("No account presentation show call is expected.");
    }];
    
    [self.identityService showAccountViewWithPresentation:^(NSURLRequest * _Nonnull request, SRGIdentityNavigationAction (^ _Nonnull URLHandler)(NSURL * _Nonnull)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestShowAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    } dismissal:^{}];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:showObserver];
    }];
}

- (void)testAccountViewWithPresentationMultipleURLHandler
{
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityTestShowAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    __block SRGIdentityNavigationAction (^currentURLHandler)(NSURL *) = nil;
    
    [self.identityService showAccountViewWithPresentation:^(NSURLRequest * _Nonnull request, SRGIdentityNavigationAction (^ _Nonnull URLHandler)(NSURL * _Nonnull)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestShowAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
        currentURLHandler = URLHandler;
    } dismissal:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestDismissalAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    SRGIdentityNavigationAction navigationAction1 = currentURLHandler(TestIgnored1CallbackURL(self.identityService));
    XCTAssertEqual(navigationAction1, SRGIdentityNavigationActionAllow);
    SRGIdentityNavigationAction navigationAction2 = currentURLHandler(TestIgnored2CallbackURL(self.identityService));
    XCTAssertEqual(navigationAction2, SRGIdentityNavigationActionAllow);
    SRGIdentityNavigationAction navigationAction3 = currentURLHandler(TestIgnored3CallbackURL());
    XCTAssertEqual(navigationAction3, SRGIdentityNavigationActionAllow);
    
    SRGIdentityNavigationAction navigationAction4 = currentURLHandler(TestLogoutCallbackURL(self.identityService));
    XCTAssertEqual(navigationAction4, SRGIdentityNavigationActionCancel);
    SRGIdentityNavigationAction navigationAction5 = currentURLHandler(TestAccountDeletedCallbackURL(self.identityService));
    XCTAssertEqual(navigationAction5, SRGIdentityNavigationActionCancel);
    SRGIdentityNavigationAction navigationAction6 = currentURLHandler(TestUnauthorizedCallbackURL(self.identityService));
    XCTAssertEqual(navigationAction6, SRGIdentityNavigationActionCancel);
}

- (void)testAccountViewWithPresentationLogoutURLHandler
{
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityTestShowAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    __block SRGIdentityNavigationAction (^currentURLHandler)(NSURL *) = nil;
    
    [self.identityService showAccountViewWithPresentation:^(NSURLRequest * _Nonnull request, SRGIdentityNavigationAction (^ _Nonnull URLHandler)(NSURL * _Nonnull)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestShowAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
        currentURLHandler = URLHandler;
    } dismissal:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestDismissalAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    __block BOOL dismissalAccountPresentationReceived = NO;
    __block BOOL userDidLogoutReceived = NO;
    
    [self expectationForNotification:SRGIdentityTestDismissalAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        
        if (!dismissalAccountPresentationReceived && !userDidLogoutReceived) {
            dismissalAccountPresentationReceived = YES;
        }
        return YES;
    }];
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceUnauthorizedKey], @NO);
        
        if (dismissalAccountPresentationReceived && !userDidLogoutReceived) {
            userDidLogoutReceived = YES;
        }
        return YES;
    }];
    
    SRGIdentityNavigationAction navigationAction1 = currentURLHandler(TestLogoutCallbackURL(self.identityService));
    XCTAssertEqual(navigationAction1, SRGIdentityNavigationActionCancel);
    
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(dismissalAccountPresentationReceived);
    XCTAssertTrue(userDidLogoutReceived);
    
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    id dismissalObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityTestDismissalAccountPresentationNotification object:self queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No account presentation dismissal call is expected.");
    }];
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLogoutNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    SRGIdentityNavigationAction navigationAction2 = currentURLHandler(TestLogoutCallbackURL(self.identityService));
    XCTAssertEqual(navigationAction2, SRGIdentityNavigationActionCancel);
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:dismissalObserver];
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
}

- (void)testAccountViewWithPresentationAccountDeletedURLHandler
{
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityTestShowAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    __block SRGIdentityNavigationAction (^currentURLHandler)(NSURL *) = nil;
    
    [self.identityService showAccountViewWithPresentation:^(NSURLRequest * _Nonnull request, SRGIdentityNavigationAction (^ _Nonnull URLHandler)(NSURL * _Nonnull)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestShowAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
        currentURLHandler = URLHandler;
    } dismissal:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestDismissalAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    __block BOOL dismissalAccountPresentationReceived = NO;
    __block BOOL userDidLogoutReceived = NO;
    
    [self expectationForNotification:SRGIdentityTestDismissalAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        
        if (!dismissalAccountPresentationReceived && !userDidLogoutReceived) {
            dismissalAccountPresentationReceived = YES;
        }
        return YES;
    }];
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceUnauthorizedKey], @NO);
        
        if (dismissalAccountPresentationReceived && !userDidLogoutReceived) {
            userDidLogoutReceived = YES;
        }
        return YES;
    }];
    
    SRGIdentityNavigationAction navigationAction1 = currentURLHandler(TestAccountDeletedCallbackURL(self.identityService));
    XCTAssertEqual(navigationAction1, SRGIdentityNavigationActionCancel);
    
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(dismissalAccountPresentationReceived);
    XCTAssertTrue(userDidLogoutReceived);
    
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    id dismissalObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityTestDismissalAccountPresentationNotification object:self queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No account presentation dismissal call is expected.");
    }];
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLogoutNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    SRGIdentityNavigationAction navigationAction2 = currentURLHandler(TestAccountDeletedCallbackURL(self.identityService));
    XCTAssertEqual(navigationAction2, SRGIdentityNavigationActionCancel);
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:dismissalObserver];
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
}

- (void)testAccountViewWithPresentationUnauthorizedURLHandler
{
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForNotification:SRGIdentityTestShowAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    __block SRGIdentityNavigationAction (^currentURLHandler)(NSURL *) = nil;
    
    [self.identityService showAccountViewWithPresentation:^(NSURLRequest * _Nonnull request, SRGIdentityNavigationAction (^ _Nonnull URLHandler)(NSURL * _Nonnull)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestShowAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
        currentURLHandler = URLHandler;
    } dismissal:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SRGIdentityTestDismissalAccountPresentationNotification
                                                            object:self
                                                          userInfo:nil];
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    __block BOOL dismissalAccountPresentationReceived = NO;
    __block BOOL userDidLogoutReceived = NO;
    
    [self expectationForNotification:SRGIdentityTestDismissalAccountPresentationNotification object:self handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        
        if (!dismissalAccountPresentationReceived && !userDidLogoutReceived) {
            dismissalAccountPresentationReceived = YES;
        }
        return YES;
    }];
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertEqualObjects(notification.userInfo[SRGIdentityServiceUnauthorizedKey], @YES);
        
        if (dismissalAccountPresentationReceived && !userDidLogoutReceived) {
            userDidLogoutReceived = YES;
        }
        return YES;
    }];
    
    SRGIdentityNavigationAction navigationAction1 = currentURLHandler(TestUnauthorizedCallbackURL(self.identityService));
    XCTAssertEqual(navigationAction1, SRGIdentityNavigationActionCancel);
    
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(dismissalAccountPresentationReceived);
    XCTAssertTrue(userDidLogoutReceived);
    
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    id dismissalObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityTestDismissalAccountPresentationNotification object:self queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No account presentation dismissal call is expected.");
    }];
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLogoutNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    SRGIdentityNavigationAction navigationAction2 = currentURLHandler(TestUnauthorizedCallbackURL(self.identityService));
    XCTAssertEqual(navigationAction2, SRGIdentityNavigationActionCancel);
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:dismissalObserver];
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
}

@end
