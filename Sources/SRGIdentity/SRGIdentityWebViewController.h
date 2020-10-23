//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <TargetConditionals.h>

#if TARGET_OS_IOS
@import WebKit;

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

#else

API_UNAVAILABLE(tvos)
@interface SRGIdentityWebViewController : UIViewController
@end

#endif
