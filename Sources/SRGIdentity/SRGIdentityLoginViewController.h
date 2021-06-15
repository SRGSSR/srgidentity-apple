//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

/**
 *  A view controller to be presented modally, allowing a user to enter their credentials.
 */
API_AVAILABLE(tvos(9.0)) API_UNAVAILABLE(ios)
@interface SRGIdentityLoginViewController : UIViewController

/**
 *  Instantiate the view controller. The `tokenBlock` is called when a token has been retrieved, whereas the
 *  `dismissalBlock` is always called when the view controller is dismissed.
 */
- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL
                           websiteURL:(NSURL *)websiteURL
                         emailAddress:(nullable NSString *)emailAddress
                           tokenBlock:(void (^)(NSString * _Nonnull sessionToken))tokenBlock
                       dismissalBlock:(void (^)(void))dismissalBlock;

@end

NS_ASSUME_NONNULL_END
