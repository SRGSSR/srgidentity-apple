//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityService.h"

NS_ASSUME_NONNULL_BEGIN


OBJC_EXPORT NSString * const SRGServiceIdentifierCookieName;

/**
 *  Interface for internal use.
 */
@interface SRGIdentityService (Private)

- (void)loggedWithSessionToken:(NSString *)sessionToken;

@end

NS_ASSUME_NONNULL_END
