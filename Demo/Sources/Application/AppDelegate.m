//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AppDelegate.h"

#import "DemosViewController.h"

#import <SRGIdentity/SRGIdentity.h>

@implementation AppDelegate

#pragma mark UIApplicationDelegate protocol

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    SRGIdentityService *identityService = [[SRGIdentityService alloc] initWithServiceURL:[NSURL URLWithString:@"https://id.rts.ch"] accessGroup:@"VMGRRW6SG7.ch.srgssr.identity"];
    [SRGIdentityService setCurrentIdentityService:identityService];
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self.window makeKeyAndVisible];
    
    DemosViewController *demosViewController = [[DemosViewController alloc] init];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:demosViewController];
    return YES;
}

@end
