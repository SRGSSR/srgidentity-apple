//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Convenience macro for localized strings associated with the framework.
 */
#define SRGIdentityLocalizedString(key, comment) [SWIFTPM_MODULE_BUNDLE localizedStringForKey:(key) value:@"" table:nil]

/**
 *  Return the recommended resource name for the main resource (xib, storyboard) associated with a class.
 */
OBJC_EXPORT NSString *SRGIdentityResourceNameForUIClass(Class cls);

NS_ASSUME_NONNULL_END
