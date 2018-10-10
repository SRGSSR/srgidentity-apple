//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UIWindow+SRGIdentity.h"

@implementation UIWindow (SRGIdentity)

- (UIViewController *)srgidentity_topViewController
{
    UIViewController *topViewController = self.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    return topViewController;
}

@end
