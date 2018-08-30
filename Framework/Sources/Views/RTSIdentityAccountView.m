//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RTSIdentityAccountView.h"

#import <WebKit/WebKit.h>

static void commonInit(RTSIdentityAccountView *self);

@interface RTSIdentityAccountView () <WKNavigationDelegate>

@property (weak, nonatomic) WKWebView *webView;

@end

@implementation RTSIdentityAccountView

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

- (void)setService:(RTSIdentityService *)service {
    _service = service;
    
    if (service) {
        NSURL *URL = [NSURL URLWithString:@"user/profile" relativeToURL:self.service.serviceURL];
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:URL];
        [request addValue:[NSString stringWithFormat:@"identity.provider.sid=%@", self.service.sessionToken] forHTTPHeaderField:@"Cookie"];
        [self.webView loadRequest:[NSURLRequest requestWithURL:URL]];
    }
    else {
        [self.webView stopLoading];
    }
}

@end

static void commonInit(RTSIdentityAccountView *self)
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
