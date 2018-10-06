//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

@class SFSafariViewController;

#import "SRGAuthentificationRequest.h"
#import "SRGAuthentificationDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/*! @brief An iOS specific external user-agent that uses the best possible user-agent available
        depending on the version of iOS to present the request.
 */
@interface SRGAuthentificationBrowserAgent : NSObject

/**
 *  Unavailable. Please use `initWithPresentingViewController:`
 */
- (instancetype)init NS_UNAVAILABLE;

/*! @brief The designated initializer.
    @param presentingViewController The view controller from which to present the
        \SFSafariViewController.
    @param redirectScheme The necessery scheme to get the call back-
 */
- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController NS_DESIGNATED_INITIALIZER;

/*! @brief Presents the request in the external user-agent.
 @param request The request to be presented in the external user-agent.
 @param session The @c OIDExternalUserAgentSession instance that initiates presenting the UI.
 Concrete implementations of a @c OIDExternalUserAgent may call
 resumeExternalUserAgentFlowWithURL or failExternalUserAgentFlowWithError on session to either
 resume or fail the request.
 @return YES If the request UI was successfully presented to the user.
 */
- (BOOL)presentExternalUserAgentRequest:(SRGAuthentificationRequest *)request
                               delegate:(id <SRGAuthentificationDelegate>)delegate;

/*! @brief Dimisses the external user-agent and calls completion when the dismiss operation ends.
 @param animated Whether or not the dismiss operation should be animated.
 @remarks Has no effect if no UI is presented.
 @param completion The block to be called when the dismiss operations ends
 */
- (void)dismissExternalUserAgentAnimated:(BOOL)animated completion:(void (^)(void))completion;

@property(nonatomic, readonly) SRGAuthentificationRequest *request;

@end

NS_ASSUME_NONNULL_END
