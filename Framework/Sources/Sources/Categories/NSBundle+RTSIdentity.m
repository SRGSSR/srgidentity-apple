//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSBundle+RTSIdentity.h"

#import "RTSIdentity.h"

@implementation NSBundle (RTSIdentity)

#pragma mark Class methods

+ (instancetype)rts_identityBundle
{
    static NSBundle *s_bundle;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        NSString *bundlePath = [[NSBundle bundleForClass:[RTSIdentity class]].bundlePath stringByAppendingPathComponent:@"RTSIdentity.bundle"];
        s_bundle = [NSBundle bundleWithPath:bundlePath];
        NSAssert(s_bundle, @"Please add RTSIdentity.bundle to your project resources");
    });
    return s_bundle;
}

@end
