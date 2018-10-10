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

@interface SRGIdentityTestCase : XCTestCase

@property (nonatomic) SRGIdentityService *identityService;

@property (nonatomic, weak) id<OHHTTPStubsDescriptor> loginRequestStub;

@end

@implementation SRGIdentityTestCase

#pragma mark Setup and teardown

- (void)setUp
{
    self.identityService = [[SRGIdentityService alloc] initWithProviderURL:[NSURL URLWithString:@"https://srgssr.local"]];
    
    self.loginRequestStub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqual:@"srgssr.local"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
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
        else if ([request.URL.path containsString:@"logout"]) {
            return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                               statusCode:204
                                                  headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
        }
        else {
            return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                               statusCode:404
                                                  headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
        }
    }];
    self.loginRequestStub.name = @"Login request";
}

- (void)tearDown
{
    self.identityService = nil;
    
    // Remove all items in the keychain.
    UICKeyChainStore *keyChainStore = [UICKeyChainStore keyChainStoreWithServer:[NSURL URLWithString:@"https://srgssr.local"] protocolType:UICKeyChainStoreProtocolTypeHTTPS];
    [keyChainStore removeAllItems];
    
    [OHHTTPStubs removeStub:self.loginRequestStub];
}

#pragma mark Tests

- (void)testHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.isLoggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    NSURL *redirectURL = [NSURL URLWithString:@"srgidentity-tests://srgssr.local?token=0123456789"];
    
    [self.identityService handleCallbackURL:redirectURL];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNotNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertTrue(self.identityService.isLoggedIn);
}

- (void)testLogout
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.isLoggedIn);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    NSURL *redirectURL = [NSURL URLWithString:@"srgidentity-tests://srgssr.local?token=0123456789"];
    
    [self.identityService handleCallbackURL:redirectURL];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.isLoggedIn);
    XCTAssertNotNil(self.identityService.sessionToken);
    
    [self expectationForNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    XCTAssertTrue([self.identityService logout]);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.isLoggedIn);
    
    XCTAssertFalse([self.identityService logout]);
}

@end
