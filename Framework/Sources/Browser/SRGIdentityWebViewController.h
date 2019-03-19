//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  A basic web view controller class for in-app display.
 */
@interface SRGIdentityWebViewController : UIViewController <WKNavigationDelegate, UIScrollViewDelegate>

/**
 *  Create an instance loading the specified URL request. The optional decision handler is called whenever navigation
 *  to another URL occurs within the browser, letting you decide the policy to apply. If no decision handler is provided,
 *  the applied policy is `WKNavigationActionPolicyAllow`.
 */
- (instancetype)initWithRequest:(NSURLRequest *)request decisionHandler:(WKNavigationActionPolicy (^ _Nullable)(NSURL *URL))decisionHandler;

@end

NS_ASSUME_NONNULL_END
