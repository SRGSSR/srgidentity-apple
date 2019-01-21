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
                    NSDictionary<NSString *, id> *account = @{ @"id" : @(1234),
                                                               @"email" : @"test@srgssr.ch",
                                                               @"display_name": @"Play SRG",
                                                               @"firstname": @"Play",
                                                               @"lastname": @"SRG",
                                                               @"gender": @"other",
                                                               @"date_of_birth": @"2001-01-01" };
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
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
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
    
    [self.identityService handleCallbackURL:TestLogoutCallbackURL(self.identityService)];
    
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
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestAccountDeletedCallbackURL(self.identityService)];
    
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
    
    [self.identityService handleCallbackURL:TestUnauthorizedCallbackURL(self.identityService)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
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

@end
