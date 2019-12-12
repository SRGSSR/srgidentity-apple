//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityLoginViewController.h"

#import "NSBundle+SRGIdentity.h"

@implementation SRGIdentityLoginViewController

#pragma mark Object lifecycle

- (instancetype)initWithEmailAddress:(nullable NSString *)emailAddress
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:SRGIdentityResourceNameForUIClass(self.class) bundle:NSBundle.srg_identityBundle];
    return [storyboard instantiateInitialViewController];
}

- (instancetype)init
{
    return [self initWithEmailAddress:nil];
}

@end
