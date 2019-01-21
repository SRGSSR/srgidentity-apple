//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DemosViewController.h"

#import "AppDelegate.h"
#import "WebViewController.h"

#import <SRGIdentity/SRGIdentity.h>

static NSString * const LastLoggedInEmailAddress = @"LastLoggedInEmailAddress";

@interface DemosViewController ()

@property (nonatomic, weak) IBOutlet UILabel *displayNameLabel;
@property (nonatomic, weak) IBOutlet UIButton *accountButton;

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
                                             selector:@selector(didLogin:)
                                                 name:SRGIdentityServiceUserDidLoginNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUpdateAccount:)
                                                 name:SRGIdentityServiceDidUpdateAccountNotification
                                               object:nil];
    
    [self reloadData];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"SRG Identity demo", nil);
}

#pragma mark UI

- (void)reloadData
{
    SRGIdentityService *identityService = SRGIdentityService.currentIdentityService;
    
    if (identityService.loggedIn) {
        self.displayNameLabel.text = identityService.account.displayName ?: identityService.emailAddress ?: @"-";
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Logout", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(logout:)];
    }
    else {
        self.displayNameLabel.text = NSLocalizedString(@"Not logged in", nil);
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Login", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(login:)];
    }
    
    self.accountButton.hidden = ! identityService.loggedIn;
}

#pragma mark Actions

- (IBAction)showAccount:(id)sender
{
    [SRGIdentityService.currentIdentityService prepareAccountRequestWithPresentation:^(NSURLRequest * _Nonnull request, SRGIdentityNavigationAction (^ _Nonnull URLHandler)(NSURL * _Nonnull)) {
        WebViewController *webViewController = [[WebViewController alloc] initWithRequest:request];
        webViewController.title = NSLocalizedString(@"Account", nil);
        webViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
                                                                                              style:UIBarButtonItemStyleDone
                                                                                             target:self
                                                                                             action:@selector(closeAccount:)];
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:webViewController];
        [self presentViewController:navigationController animated:YES completion:nil];
    }];
}

- (void)closeAccount:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)login:(id)sender
{
    NSString *lastEmailAddress = [NSUserDefaults.standardUserDefaults stringForKey:LastLoggedInEmailAddress];
    [SRGIdentityService.currentIdentityService loginWithEmailAddress:lastEmailAddress];
}

- (void)logout:(id)sender
{
    [SRGIdentityService.currentIdentityService logout];
}

#pragma mark Notifications

- (void)didLogin:(NSNotification *)notification
{
    [self reloadData];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    [self reloadData];
    
    NSString *emailAddress = SRGIdentityService.currentIdentityService.emailAddress;;
    if (emailAddress) {
        [NSUserDefaults.standardUserDefaults setObject:emailAddress forKey:LastLoggedInEmailAddress];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
}

@end
