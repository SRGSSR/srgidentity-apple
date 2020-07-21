//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSBundle+SRGIdentity.h"

#import "SRGIdentityService.h"

NSString *SRGIdentityResourceNameForUIClass(Class cls)
{
    NSString *name = NSStringFromClass(cls);
#if TARGET_OS_TV
    return [name stringByAppendingString:@"~tvos"];
#else
    return [name stringByAppendingString:@"~ios"];
#endif
}
