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

static NSURL *TestCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&token=%@", TestWebserviceURL().host, identityService.identifier, token];
    return [NSURL URLWithString:URLString];
}

@interface SRGIdentityTestCase : XCTestCase

@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic, weak) id<OHHTTPStubsDescriptor> loginRequestStub;

@end

@implementation SRGIdentityTestCase

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

- (void)testHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNotNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertTrue(self.identityService.loggedIn);
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

    [self.identityService handleCallbackURL:TestCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertNotNil(self.identityService.sessionToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
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

    [self.identityService handleCallbackURL:TestCallbackURL(self.identityService, TestValidToken)];
    
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
    XCTAssertNotNil(self.identityService.sessionToken);
    XCTAssertNotNil(self.identityService.account);
    
    XCTAssertTrue(self.identityService.loggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
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
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestCallbackURL(self.identityService, @"invalid_token")];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    
    // Wait until account information is requested. The token is invalid, the user unauthorized and therefore logged out automatically
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

@end
