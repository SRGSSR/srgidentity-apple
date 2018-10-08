//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

#import "SRGAuthentificationRequest.h"
#import "SRGAuthentificationDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  An iOS specific external user-agent that uses the best possible user-agent available regarding the iOS version.
 *  Inspired by https://github.com/openid/AppAuth-iOS
 */
@interface SRGAuthentificationController : NSObject

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
@property(nonatomic, nullable, readonly) SRGAuthentificationRequest *request;

/**
 *  Presents the request in an external user-agent.
 *
 *  @param request The request to be presented.
 *  @param delegate The request session delegate.
 *
 *  @return YES If the request UI was successfully presented to the user.
 *
 *  @Discussion The instance may call `resumeAuthentificationWithURL:` or `failAuthentificationWithError:` on delegate
 *  to either resume or fail the request.
 */
- (BOOL)presentControllerWithRequest:(SRGAuthentificationRequest *)request
                            delegate:(id <SRGAuthentificationDelegate>)delegate;

/**
 *  Dimisses the external user-agent and calls completion when the dismiss operation ends.
 */
- (void)dismissExternalUserAgentAnimated:(BOOL)animated completion:(void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
