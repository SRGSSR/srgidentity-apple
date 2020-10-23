//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Standard images from Identity bundle.
 */
@interface UIImage (SRGIdentityImages)

/**
 *  Return the specified image from the Identity bundle, `nil` if not found.
 */
+ (nullable UIImage *)srg_identityImageNamed:(NSString *)imageName;

@end

NS_ASSUME_NONNULL_END
