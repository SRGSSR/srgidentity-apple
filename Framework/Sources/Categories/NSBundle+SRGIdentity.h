//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Convenience macro for localized strings associated with the framework.
 */
#define SRGIdentityLocalizedString(key, comment) [[NSBundle srg_identityBundle] localizedStringForKey:(key) value:@"" table:nil]

@interface NSBundle (SRGIdentity)

/**
 *  The framework resource bundle.
 */
+ (NSBundle *)srg_identityBundle;

@end

NS_ASSUME_NONNULL_END
