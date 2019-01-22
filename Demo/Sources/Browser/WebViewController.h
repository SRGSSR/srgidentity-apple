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
@interface WebViewController : UIViewController <WKNavigationDelegate, UIScrollViewDelegate>

/**
 *  Create an instance.
 */
- (instancetype)initWithRequest:(NSURLRequest *)request decisionHandler:(WKNavigationActionPolicy (^ _Nullable)(NSURL *))decisionHandler;

@end

NS_ASSUME_NONNULL_END
