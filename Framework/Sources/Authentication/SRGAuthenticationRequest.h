//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRGAuthenticationRequest : NSObject

/**
 *  The complete authentication request URL.
 *
 *  @discussion The URL to be opened in an external UI (i.e. browser or SFSafariViewController)
 */
@property (nonatomic, readonly) NSURL *URL;

/**
 *  The redirect URL to open the application.
 *
 *  @discussion The external user-agent request has a redirect URL, which has a custom scheme. If the application has no
 *  custom scheme, the redirect won't be catch.
 */
@property (nonatomic, readonly) NSURL *redirectURL;

/**
 *  Unavailable. Please use `initWithPresentingViewController:`
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 *  Create instance.
 */
- (instancetype)initWithServiceURL:(NSURL *)serviceURL emailAddress:(nullable NSString *)emailAddress NS_DESIGNATED_INITIALIZER;

/**
 *  Confirm that the redirect reponse URL is conform to the request.
 */
- (BOOL)shouldHandleReponseURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
