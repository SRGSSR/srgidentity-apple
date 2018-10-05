//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DemosViewController.h"

#import "AccountViewController.h"
#import "LoginViewController.h"

#import <AVKit/AVKit.h>
#import <SRGIdentity/SRGIdentity.h>

@interface DemosViewController ()

@property (weak, nonatomic) IBOutlet UILabel *displayNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *loginButton;
@property (weak, nonatomic) IBOutlet UIButton *accountButton;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;
@property (weak, nonatomic) IBOutlet UISwitch *testModeSwitch;

@property (nonatomic) SRGNetworkRequest *accountRequest;

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
    [self reloadData];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userChanged:)
                                                 name:SRGIdentityServiceUserLoggedInNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userChanged:)
                                                 name:SRGIdentityServiceUserLoggedOutNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userChanged:)
                                                 name:SRGIdentityServiceUserMetadatasUpdateNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self refresh];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return [NSString stringWithFormat:@"SRGIdentity %@ (demo %@)", SRGIdentityMarketingVersion(), @([NSBundle.mainBundle.infoDictionary[@"DemoNumber"] integerValue])];
}

#pragma mark Datas

- (void)refresh
{
    [self.accountRequest cancel];
    
    if (SRGIdentityService.currentIdentityService.logged) {
        self.displayNameLabel.text = @"Refreshing…";
        self.accountRequest = [SRGIdentityService.currentIdentityService accountWithCompletionBlock:^(SRGAccount * _Nullable account, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            [self reloadData];
            if ([error.domain isEqualToString:@"http"] && error.code == 401) {
                self.displayNameLabel.text = @"Session expired.";
                [SRGIdentityService.currentIdentityService logout];
            }
        }];
        [self.accountRequest resume];
    }
    else {
        self.displayNameLabel.text = @"Not logged.";
    }
}

- (void)reloadData {
    BOOL isLogged = SRGIdentityService.currentIdentityService.logged;
    
    self.displayNameLabel.text = isLogged ? SRGIdentityService.currentIdentityService.displayName : @"Not logged.";
    self.loginButton.enabled = self.testModeSwitch.on || !isLogged;
    self.accountButton.enabled = self.testModeSwitch.on || isLogged;;
    self.logoutButton.enabled = self.testModeSwitch.on || isLogged;;
}

#pragma mark Actions

- (IBAction)login:(id)sender {
    LoginViewController *viewController = [[LoginViewController alloc] initWithTitle:@"Login"];
    UINavigationController *navigationViewController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navigationViewController animated:YES completion:nil];
}

- (IBAction)account:(id)sender {
    AccountViewController *viewController = [[AccountViewController alloc] initWithTitle:@"Account"];
    UINavigationController *navigationViewController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navigationViewController animated:YES completion:nil];
}

- (IBAction)logout:(id)sender {
    [SRGIdentityService.currentIdentityService logout];
}

- (IBAction)testModeToggle:(id)sender {
    [self reloadData];
}

#pragma mark Notifications

- (void)userChanged:(NSNotification *)notification
{
    [self reloadData];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self refresh];
}

@end
