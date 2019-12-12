//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityLoginViewController.h"

#import "NSBundle+SRGIdentity.h"

@implementation SRGIdentityLoginViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:SRGIdentityResourceNameForUIClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

@end
