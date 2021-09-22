//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AppDelegate.h"

#import "Application.h"

@import SRGIdentity;

@implementation AppDelegate

#pragma mark UIApplicationDelegate protocol

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://hummingbird.rts.ch/api/profile"]
                                                                                       websiteURL:[NSURL URLWithString:@"https://www.rts.ch/profile"]];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(userDidLogout:)
                                               name:SRGIdentityServiceUserDidLogoutNotification
                                             object:SRGIdentityService.currentIdentityService];
    
    if (@available(iOS 13, tvOS 13, *)) {}
    else {
        self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        [self.window makeKeyAndVisible];
        self.window.rootViewController = ApplicationRootViewController();
    }
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options API_AVAILABLE(ios(13.0))
{
    return [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:connectingSceneSession.role];
}

#pragma mark Notifications

- (void)userDidLogout:(NSNotification *)notification
{
    if ([notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Information", nil)
                                                                                 message:NSLocalizedString(@"You have been logged out. Please login again to synchronize your data.", nil)
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    }
}

@end
