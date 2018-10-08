//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

#import "SRGAuthenticationRequest.h"
#import "SRGAuthenticationDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  An iOS specific external user-agent that uses the best possible user-agent available regarding the iOS version.
 *  Inspired by https://github.com/openid/AppAuth-iOS
 */
@interface SRGAuthenticationController : NSObject

/**
 *  Unavailable. Please use `initWithPresentingViewController:`
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 *  The designated initializer.
 *
 *  @param presentingViewController The view controller from which to present the SFSafariViewController will be presented.
 */
- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController NS_DESIGNATED_INITIALIZER;

/**
 *  The request, if any.
 */
@property(nonatomic, nullable, readonly) SRGAuthenticationRequest *request;

/**
 *  Presents the request in an external user-agent.
 *
 *  @param request The request to be presented.
 *  @param delegate The request session delegate.
 *
 *  @return YES If the request UI was successfully presented to the user.
 *
 *  @Discussion The instance may call `resumeauthenticationWithURL:` or `failauthenticationWithError:` on delegate
 *  to either resume or fail the request.
 */
- (BOOL)presentControllerWithRequest:(SRGAuthenticationRequest *)request
                            delegate:(id <SRGAuthenticationDelegate>)delegate;

/**
 *  Dimisses the external user-agent and calls completion when the dismiss operation ends.
 */
- (void)dismissExternalUserAgentAnimated:(BOOL)animated completion:(void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
