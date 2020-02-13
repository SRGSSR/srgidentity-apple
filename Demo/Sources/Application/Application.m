//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Application.h"

#import "DemosViewController.h"

UIViewController *ApplicationRootViewController(void)
{
    DemosViewController *demosViewController = [[DemosViewController alloc] init];
    return [[UINavigationController alloc] initWithRootViewController:demosViewController];
}
