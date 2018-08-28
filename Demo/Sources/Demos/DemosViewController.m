//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DemosViewController.h"

#import <AVKit/AVKit.h>
#import <RTSIdentity/RTSIdentity.h>

@interface DemosViewController ()

@end

@implementation DemosViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return [NSString stringWithFormat:@"RTSIdentity %@", RTSIdentityMarketingVersion()];
}

@end
