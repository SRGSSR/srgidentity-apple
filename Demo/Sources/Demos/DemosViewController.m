//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DemosViewController.h"

#import "AccountViewController.h"
#import "LoginViewController.h"

#import <AVKit/AVKit.h>
#import <RTSIdentity/RTSIdentity.h>

@interface DemosViewController ()

@property (weak, nonatomic) IBOutlet UILabel *displayNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *loginButton;
@property (weak, nonatomic) IBOutlet UIButton *accountButton;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;

@property (nonatomic) NSURLSessionTask *sessionTask;

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
                                                 name:RTSIdentityServiceUserLoggedInNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userChanged:)
                                                 name:RTSIdentityServiceUserLoggedOutNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userChanged:)
                                                 name:RTSIdentityServiceUserMetadatasUpdateNotification
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
    return [NSString stringWithFormat:@"RTSIdentity %@", RTSIdentityMarketingVersion()];
}

#pragma mark Datas

- (void)refresh
{
    [self.sessionTask cancel];
    
    if ([RTSIdentityService currentIdentityService].isLogged) {
        self.displayNameLabel.text = @"Refreshing…";
        self.sessionTask = [[RTSIdentityService currentIdentityService] accountWithCompletionBlock:^(RTSAccount * _Nullable account, NSError * _Nullable error) {
            if (! error) {
                [self reloadData];
            }
            else {
                self.displayNameLabel.text = @"Session expired.";
            }
        }];
        [self.sessionTask resume];
    }
    else {
        self.displayNameLabel.text = @"Not logged.";
    }
}

- (void)reloadData {
    BOOL isLogged = [RTSIdentityService currentIdentityService].isLogged;
    
    self.displayNameLabel.text = isLogged ? [RTSIdentityService currentIdentityService].displayName : @"Not logged.";
    self.loginButton.enabled = !isLogged;
    self.accountButton.enabled = isLogged;
    self.logoutButton.enabled = isLogged;
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
    [[RTSIdentityService currentIdentityService] logout];
}

- (void)userChanged:(NSNotification *)notification
{
    if([notification.name isEqualToString:RTSIdentityServiceUserLoggedInNotification]) {
        [self refresh];
    }
    else {
        [self reloadData];
    }
}

@end
