//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RTSIdentityService.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Interface for internal use.
 */
@interface RTSIdentityService (Private)

- (void)loggedWithSessionToken:(NSString *)sessionToken;

@end

NS_ASSUME_NONNULL_END
