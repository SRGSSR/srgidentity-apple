//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Convenience macro for localized strings associated with the framework.
 */
#define RTSIdentityLocalizedString(key, comment) [[NSBundle rts_identityBundle] localizedStringForKey:(key) value:@"" table:nil]

@interface NSBundle (RTSIdentity)

/**
 *  The framework resource bundle.
 */
+ (NSBundle *)rts_identityBundle;

@end

NS_ASSUME_NONNULL_END
