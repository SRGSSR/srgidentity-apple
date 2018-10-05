//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityLoginView.h"
#import "SRGIdentityService+Private.h"

#import <libextobjc/libextobjc.h>
#import <WebKit/WebKit.h>

static void commonInit(SRGIdentityLoginView *self);

@interface SRGIdentityLoginView () <WKNavigationDelegate>

@property (weak, nonatomic) WKWebView *webView;

@end

@implementation SRGIdentityLoginView

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
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"token"];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    if (queryItem) {
        [self.service loggedWithSessionToken:queryItem.value];
        (self.completionBlock) ? self.completionBlock(nil) : nil;
    }
}

#pragma mark Getters and setters

- (void)setService:(SRGIdentityService *)service {
    _service = service;
    
    if (service) {
        NSString *loginURLString = [NSString stringWithFormat:@"responsive/login?withcode=true&redirect=%@", self.service.serviceURL.absoluteString];
        NSURL *URL = [NSURL URLWithString:loginURLString relativeToURL:self.service.serviceURL];
        if (self.service.emailAddress) {
            NSURLQueryItem *emailQueryItem = [[NSURLQueryItem alloc] initWithName:@"email" value:self.service.emailAddress];
            
            NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:YES];
            URLComponents.queryItems = [URLComponents.queryItems arrayByAddingObject:emailQueryItem];
            URL = URLComponents.URL;
        }
        [self.webView loadRequest:[NSURLRequest requestWithURL:URL]];
    }
    else {
        [self.webView stopLoading];
    }
}

@end

static void commonInit(SRGIdentityLoginView *self)
{
    self.backgroundColor = UIColor.blackColor;
        
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.bounds];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.navigationDelegate = self;
    
    webView.customUserAgent = @"Mozilla/5.0 (iPhoneXi; CPU iPhone OS 11_4_0 like Mac OS Xi) AppleWebKit/603.3.8 (KHTML, like Gecko) Version/11.4 Mobile/14G60 Safari/602.1";
    
    // Scroll view content insets are adjusted automatically, but only for the scroll view at index 0. This
    // is the main content web view, we therefore put it at index 0
    [self insertSubview:webView atIndex:0];
    self.webView = webView;
}
