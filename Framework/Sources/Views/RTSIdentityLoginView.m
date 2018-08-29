//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RTSIdentityLoginView.h"
#import "RTSIdentityService+Private.h"

#import <libextobjc/libextobjc.h>
#import <WebKit/WebKit.h>

static void commonInit(RTSIdentityLoginView *self);

@interface RTSIdentityLoginView () <WKNavigationDelegate>

@property (weak, nonatomic) WKWebView *webView;

@end

@implementation RTSIdentityLoginView

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

#pragma mark WKWebViewDelegate protocol implementation

- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:webView.URL resolvingAgainstBaseURL:NO];
    if ([URLComponents.host isEqualToString:@"identity"]) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"token"];
        NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
        if (! queryItem || ! queryItem.value) {
            (self.completionBlock) ? self.completionBlock([NSError errorWithDomain:@"authentification" code:1012 userInfo:nil]) : nil;
            return;
        }
        [self.service loggedWithAccessToken:queryItem.value];
        
        (self.completionBlock) ? self.completionBlock(nil) : nil;
    }
}

#pragma mark Getters and setters

- (void)setService:(RTSIdentityService *)service {
    _service = service;
    
    if (service) {
        NSURL *URL = [NSURL URLWithString:@"responsive/login?redirect=https://identity" relativeToURL:self.service.serviceURL];
        [self.webView loadRequest:[NSURLRequest requestWithURL:URL]];
    }
    else {
        [self.webView stopLoading];
    }
}

@end

static void commonInit(RTSIdentityLoginView *self)
{
    self.backgroundColor = [UIColor blackColor];
        
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.bounds];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.navigationDelegate = self;
    
    // Scroll view content insets are adjusted automatically, but only for the scroll view at index 0. This
    // is the main content web view, we therefore put it at index 0
    [self insertSubview:webView atIndex:0];
    self.webView = webView;
}
