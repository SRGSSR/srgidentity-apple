//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <TargetConditionals.h>

#if TARGET_OS_IOS

#import "SRGIdentityWebViewController.h"

#import "NSBundle+SRGIdentity.h"
#import "SRGIdentityModalTransition.h"

@import libextobjc;
@import MAKVONotificationCenter;
@import SRGNetwork;

@interface SRGIdentityWebViewController ()

@property (nonatomic) NSURLRequest *request;
@property (nonatomic, copy) WKNavigationActionPolicy (^decisionHandler)(NSURL *);

@property (nonatomic, weak) UIProgressView *progressView;
@property (nonatomic, weak) WKWebView *webView;
@property (nonatomic, weak) UILabel *errorLabel;

@end

@implementation SRGIdentityWebViewController

#pragma mark Object lifecycle

- (instancetype)initWithRequest:(NSURLRequest *)request decisionHandler:(WKNavigationActionPolicy (^)(NSURL *URL))decisionHandler
{
    SRGIdentityWebViewController *webViewController = [[SRGIdentityWebViewController alloc] init];
    webViewController.request = request;
    webViewController.decisionHandler = decisionHandler;
    return webViewController;
}

- (void)dealloc
{
    // Avoid iOS 9 crash: https://stackoverflow.com/questions/35529080/wkwebview-crashes-on-deinit
    self.webView.scrollView.delegate = nil;
    
    self.webView = nil;             // Unregister KVO
}

#pragma mark Getters and setters

- (void)setWebView:(WKWebView *)webView
{
    [_webView removeObserver:self keyPath:@keypath(_webView.estimatedProgress)];
    
    _webView = webView;
    
    if (_webView) {
        @weakify(self)
        [_webView addObserver:self keyPath:@keypath(webView.estimatedProgress) options:NSKeyValueObservingOptionNew block:^(MAKVONotification *notification) {
            @strongify(self)
            self.progressView.progress = self.webView.estimatedProgress;
        }];
    }
}

#pragma mark View lifecycle

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    view.backgroundColor = UIColor.whiteColor;
    self.view = view;
    
    [self layoutWebViewInView:view];
    [self layoutProgressViewInView:view];
    [self layoutErrorLabelInView:view];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Force properties to avoid overrides with UIAppearance
    UIProgressView *progressViewAppearance = [UIProgressView appearanceWhenContainedInInstancesOfClasses:@[self.class]];
    progressViewAppearance.progressTintColor = nil;
    progressViewAppearance.trackTintColor = nil;
    progressViewAppearance.progressImage = nil;
    progressViewAppearance.trackImage = nil;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self
                                                                                           action:@selector(refresh:)];
    
    [self.webView loadRequest:self.request];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.movingFromParentViewController || self.beingDismissed) {
        [self.webView stopLoading];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateContentInsets];
}

#pragma mark Layout helpers

- (void)layoutWebViewInView:(UIView *)view
{
    WKWebView *webView = [[WKWebView alloc] init];
    webView.backgroundColor = UIColor.clearColor;
    webView.navigationDelegate = self;
    webView.scrollView.delegate = self;
    [view addSubview:webView];
    self.webView = webView;
    
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [webView.leadingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.leadingAnchor],
        [webView.trailingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.trailingAnchor],
        [webView.topAnchor constraintEqualToAnchor:view.topAnchor],
        [webView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];
}

- (void)layoutProgressViewInView:(UIView *)view
{
    UIProgressView *progressView = [[UIProgressView alloc] init];
    [view addSubview:progressView];
    self.progressView = progressView;
    
    progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [progressView.topAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.topAnchor],
        [progressView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [progressView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor]
    ]];
}

- (void)layoutErrorLabelInView:(UIView *)view
{
    UILabel *errorLabel = [[UILabel alloc] init];
    errorLabel.font = [UIFont systemFontOfSize:20.f];
    errorLabel.textColor = UIColor.grayColor;
    [view addSubview:errorLabel];
    self.errorLabel = errorLabel;
    
    errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [errorLabel.centerYAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.centerYAnchor],
        [errorLabel.leadingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.leadingAnchor constant:40.f],
        [errorLabel.trailingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.trailingAnchor constant:40.f]
    ]];
}

#pragma mark UI

- (void)updateContentInsets
{
    UIScrollView *scrollView = self.webView.scrollView;
    
    // Must adjust depending on the web page viewport-fit setting, see https://modelessdesign.com/backdrop/283
    if (scrollView.contentInsetAdjustmentBehavior == UIScrollViewContentInsetAdjustmentAlways) {
        scrollView.contentInset = UIEdgeInsetsZero;
    }
    else {
        scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
        scrollView.contentInset = UIEdgeInsetsMake(self.view.safeAreaInsets.top, 0.f, self.view.safeAreaInsets.bottom, 0.f);
    }
}

#pragma mark UIScrollViewDelegate protocol

- (void)scrollViewDidChangeAdjustedContentInset:(UIScrollView *)scrollView
{
    [self updateContentInsets];
}

#pragma mark WKNavigationDelegate protocol

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    self.errorLabel.text = nil;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.progressView.alpha = 1.f;
    }];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    self.errorLabel.text = nil;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.webView.alpha = 1.f;
        self.progressView.alpha = 0.f;
    }];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        self.errorLabel.text = [NSHTTPURLResponse srg_localizedStringForURLErrorCode:error.code];
        
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
    if (self.decisionHandler) {
        decisionHandler(self.decisionHandler(navigationAction.request.URL));
    }
    else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

#pragma mark Actions

- (void)refresh:(id)sender
{
    [self.webView loadRequest:self.request];
}

@end

#endif
