//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityAccountView.h"

#import "SRGIdentityService+private.h"

#import <WebKit/WebKit.h>

static void commonInit(SRGIdentityAccountView *self);

@interface SRGIdentityAccountView () <WKNavigationDelegate>

@property (weak, nonatomic) WKWebView *webView;

@end

/*
 *  To have the correct authentification we need two actions:
 *  - Set Cookie in the header for the first request.
 *  - Set Cookie in the storage via a javascript for other requests (AJAX, next page…).
 */

@implementation SRGIdentityAccountView

#pragma mark Object lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        commonInit(self);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        commonInit(self);
    }
    return self;
}

#pragma mark Getters and setters

- (void)setService:(SRGIdentityService *)service {
    if (! [_service isEqual:service]) {
        [self.webView stopLoading];
        
        _service = service;
        
        [self replaceWebviewWithService:service];
        
        if (service) {
            NSURL *URL = [NSURL URLWithString:@"user/profile" relativeToURL:self.service.serviceURL];
            NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:URL];
            // Set Cookie header for the first request.
            [request addValue:[NSString stringWithFormat:@"%@=%@", SRGServiceIdentifierCookieName, self.service.sessionToken ?: @""] forHTTPHeaderField:@"Cookie"];
            [self.webView loadRequest:request];
        }
    }
}

#pragma mark Helpers

- (void)replaceWebviewWithService:(SRGIdentityService *)service
{
    // Set Cookie for other requests than the first one.
    NSString *cookieValue = service.sessionToken ?: @"";
    
    NSString *cookieDomain = @"";
    if (service.serviceURL.host) {
        NSArray<NSString *> *subHosts = [service.serviceURL.host componentsSeparatedByString:@"."];
        if (subHosts.count > 1) {
            cookieDomain = [NSString stringWithFormat:@".%@.%@", subHosts[subHosts.count - 2], subHosts[subHosts.count - 1]];
        }
    }
    
    static NSDateFormatter *dateFormatter = nil;
    if (!dateFormatter) {
        NSLocale *en_US_POSIX = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setLocale:en_US_POSIX];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [dateFormatter setDateFormat:@"EEE, d MMM yyyy HH:mm:ss zzz"];
    }
    
    NSDate *cookieExpiresDate = (service.sessionToken) ? [NSDate dateWithTimeIntervalSinceNow:3600] : [NSDate dateWithTimeIntervalSince1970:0];
    NSString *cookieExpires = [dateFormatter stringFromDate:cookieExpiresDate];
    
    NSString *javaScript = javaScript = [NSString stringWithFormat:@"document.cookie = '%@=%@;domain=%@;path=/;expires=%@';", SRGServiceIdentifierCookieName, cookieValue, cookieDomain, cookieExpires];
    
    // https://stackoverflow.com/questions/26573137/can-i-set-the-cookies-to-be-used-by-a-wkwebview
    WKUserContentController* userContentController = WKUserContentController.new;
    WKUserScript * cookieScript = [[WKUserScript alloc] initWithSource:javaScript
                                                         injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [userContentController addUserScript:cookieScript];
    WKWebViewConfiguration* webViewConfig = WKWebViewConfiguration.new;
    webViewConfig.userContentController = userContentController;
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.bounds configuration:webViewConfig];

    webView.customUserAgent = @"Mozilla/5.0 (iPhoneXi; CPU iPhone OS 11_4_0 like Mac OS Xi) AppleWebKit/603.3.8 (KHTML, like Gecko) Version/11.4 Mobile/14G60 Safari/602.1";
    
    [self.webView removeFromSuperview];
    
    // Scroll view content insets are adjusted automatically, but only for the scroll view at index 0. This
    // is the main content web view, we therefore put it at index 0
    [self insertSubview:webView atIndex:0];
    self.webView = webView;
}
@end

static void commonInit(SRGIdentityAccountView *self)
{
    self.backgroundColor = [UIColor blackColor];
        
    [self replaceWebviewWithService:nil];
}
