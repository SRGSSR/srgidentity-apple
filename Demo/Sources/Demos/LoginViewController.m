//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "LoginViewController.h"

@interface LoginViewController ()

@property (weak, nonatomic) IBOutlet SRGIdentityLoginView *identityLoginView;

@end

@implementation LoginViewController

#pragma mark Object lifecycle

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

- (instancetype)initWithTitle:(NSString *)title
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass([self class]) bundle:nil];
    LoginViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.title = title;
    
    return viewController;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithTitle:nil];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithTitle:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [super initWithCoder:aDecoder];
}

#pragma mark View lifecycle

- (void)viewDidLoad {
    self.identityLoginView.service = [SRGIdentityService currentIdentityService];
    self.identityLoginView.completionBlock = ^(NSError * _Nullable error) {
        [self dismiss:self.identityLoginView];
    };
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(dismiss:)];
}

#pragma mark Actions

- (void)dismiss:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
