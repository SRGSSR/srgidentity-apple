//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DemosViewController.h"

#import "AppDelegate.h"

#import <AVKit/AVKit.h>
#import <SRGIdentity/SRGIdentity.h>

@interface DemosViewController ()

@property (weak, nonatomic) IBOutlet UILabel *displayNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *loginButton;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;
@property (weak, nonatomic) IBOutlet UISwitch *testModeSwitch;

@end

@implementation DemosViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userChanged:)
                                                 name:SRGIdentityServiceUserDidLoginNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userChanged:)
                                                 name:SRGIdentityServiceUserDidLogoutNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userChanged:)
                                                 name:SRGIdentityServiceDidUpdateAccountNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [self reloadData];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return [NSString stringWithFormat:NSLocalizedString(@"SRGIdentity %@ (demo %@)", nil), SRGIdentityMarketingVersion(), @([NSBundle.mainBundle.infoDictionary[@"DemoNumber"] integerValue])];
}

#pragma mark Data

- (void)reloadData
{
    BOOL isLogged = SRGIdentityService.currentIdentityService.logged;
    
    self.displayNameLabel.text = SRGIdentityService.currentIdentityService.account.displayName ?: SRGIdentityService.currentIdentityService.emailAddress ?: NSLocalizedString(@"Not logged.", nil);
    self.loginButton.enabled = self.testModeSwitch.on || !isLogged;
    self.logoutButton.enabled = self.testModeSwitch.on || isLogged;
}

#pragma mark Actions

- (IBAction)login:(id)sender
{
    [SRGIdentityService.currentIdentityService presentAuthenticationViewControllerFromViewController:self completionBlock:nil];
}

- (IBAction)logout:(id)sender
{
    [SRGIdentityService.currentIdentityService logout];
}

- (IBAction)testModeToggle:(id)sender
{
    [self reloadData];
}

#pragma mark Notifications

- (void)userChanged:(NSNotification *)notification
{
    [self reloadData];
}

@end
