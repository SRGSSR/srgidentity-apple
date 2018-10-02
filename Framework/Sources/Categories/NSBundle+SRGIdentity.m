//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSBundle+SRGIdentity.h"

#import "SRGIdentityService.h"

@implementation NSBundle (SRGIdentity)

#pragma mark Class methods

+ (instancetype)srg_identityBundle
{
    static NSBundle *s_bundle;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        NSString *bundlePath = [[NSBundle bundleForClass:[SRGIdentityService class]].bundlePath stringByAppendingPathComponent:@"SRGIdentity.bundle"];
        s_bundle = [NSBundle bundleWithPath:bundlePath];
        NSAssert(s_bundle, @"Please add SRGIdentity.bundle to your project resources");
    });
    return s_bundle;
}

@end
