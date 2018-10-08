//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  SRG Identity error constants.
 */
typedef NS_ENUM(NSInteger, SRGIdentityError) {
    /**
     *  The data which was received is invalid.
     */
    SRGIdentityErrorCodeInvalidData,
    /**
     *  The authentication process was canceled.
     */
    SRGAuthenticationCanceled,
    /**
     *  The authentication process failed to start.
     */
    SRGAuthenticationStartFailed
};

/**
 *  Common domain for SRG Identity errors.
 */
OBJC_EXPORT NSString * const SRGIdentityErrorDomain;

NS_ASSUME_NONNULL_END
