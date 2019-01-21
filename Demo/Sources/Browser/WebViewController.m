//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "WebViewController.h"

#import <libextobjc/libextobjc.h>
#import <Masonry/Masonry.h>
#import <SRGNetwork/SRGNetwork.h>

static void *s_kvoContext = &s_kvoContext;

@interface WebViewController ()

@property (nonatomic) NSURLRequest *request;
@property (nonatomic, copy) WKNavigationActionPolicy (^decidePolicyBlock)(NSURL *URL);

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;
@property (nonatomic, weak) WKWebView *webView;
@property (nonatomic, weak) UIActivityIndicatorView *loadingView;
@property (nonatomic, weak) IBOutlet UILabel *errorLabel;

@end

@implementation WebViewController

#pragma mark Object lifecycle

- (instancetype)initWithRequest:(NSURLRequest *)request decidePolicy:(WKNavigationActionPolicy (^)(NSURL *URL))decidePolicyBlock
{
    if (self = [super init]) {
        self.request = request;
        self.decidePolicyBlock = decidePolicyBlock;
    }
    return self;
}

- (void)dealloc
{
    self.webView = nil;             // Unregister KVO
}

#pragma mark Getters and setters

- (void)setWebView:(WKWebView *)webView
{
    [_webView removeObserver:self forKeyPath:@keypath(WKWebView.new, estimatedProgress) context:s_kvoContext];
    _webView = webView;
    [_webView addObserver:self forKeyPath:@keypath(WKWebView.new, estimatedProgress) options:NSKeyValueObservingOptionNew context:s_kvoContext];
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // WKWebView cannot be instantiated in storyboards, do it programmatically
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
    webView.navigationDelegate = self;
    [self.view insertSubview:webView atIndex:0];
    [webView mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11, *)) {
            make.top.equalTo(self.view);
            make.bottom.equalTo(self.view);
            make.left.equalTo(self.view.mas_safeAreaLayoutGuideLeft);
            make.right.equalTo(self.view.mas_safeAreaLayoutGuideRight);
        }
        else {
            make.edges.equalTo(self.view);
        }
    }];
    self.webView = webView;
    
    UIActivityIndicatorView *loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    loadingView.hidden = YES;
    [self.view insertSubview:loadingView atIndex:0];
    [loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.errorLabel);
    }];
    self.loadingView = loadingView;
    
    self.errorLabel.text = nil;
    
    [self.webView loadRequest:self.request];
}

#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    self.loadingView.hidden = NO;
    self.errorLabel.text = nil;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.progressView.alpha = 1.f;
    }];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    self.loadingView.hidden = YES;
    self.errorLabel.text = nil;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.webView.alpha = 1.f;
        self.progressView.alpha = 0.f;
    }];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    self.loadingView.hidden = YES;
    
    NSURL *failingURL = ([error.domain isEqualToString:NSURLErrorDomain]) ? error.userInfo[NSURLErrorFailingURLErrorKey] : nil;
    if (failingURL && ! [failingURL.scheme isEqualToString:@"http"] && ! [failingURL.scheme isEqualToString:@"https"] && ! [failingURL.scheme isEqualToString:@"file"]) {
        error = nil;
    }

    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        self.errorLabel.text = [NSHTTPURLResponse srg_localizedStringForStatusCode:error.code];
        
        [UIView animateWithDuration:0.3 animations:^{
            self.progressView.alpha = 0.f;
            self.webView.alpha = 0.f;
        }];
    }
    else {
        self.errorLabel.text = nil;
        
        [webView goBack];
        
        [UIView animateWithDuration:0.3 animations:^{
            self.progressView.alpha = 0.f;
        }];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if (self.decidePolicyBlock) {
        decisionHandler(self.decidePolicyBlock(navigationAction.request.URL));
    }
    else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (context == s_kvoContext) {
        if ([keyPath isEqualToString:@keypath(WKWebView.new, estimatedProgress)]) {
            self.progressView.progress = self.webView.estimatedProgress;
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
