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
#define SRGIdentityLocalizedString(key, comment) [NSBundle.srg_identityBundle localizedStringForKey:(key) value:@"" table:nil]

/**
 *  Return the recommended resource name for the main resource (xib, storyboard) associated with a class.
 */
OBJC_EXPORT NSString *SRGIdentityResourceNameForUIClass(Class cls);

@interface NSBundle (SRGIdentity)

/**
 *  The framework resource bundle.
 */
@property (class, nonatomic, readonly) NSBundle *srg_identityBundle;

@end

NS_ASSUME_NONNULL_END
