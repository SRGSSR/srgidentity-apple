//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityLoginViewController.h"

#import "NSBundle+SRGIdentity.h"

#import <SRGNetwork/SRGNetwork.h>

@interface SRGIdentityLoginViewController ()

@property (nonatomic, copy) NSString *emailAddress;
@property (nonatomic) NSURL *webserviceURL;
@property (nonatomic) NSURL *websiteURL;

@property (nonatomic, weak) IBOutlet UITextField *emailAddressTextField;
@property (nonatomic, weak) IBOutlet UITextField *passwordTextField;

@property (nonatomic, weak) SRGRequest *loginRequest;

@end

@implementation SRGIdentityLoginViewController

#pragma mark Object lifecycle

- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL emailAddress:(NSString *)emailAddress
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:SRGIdentityResourceNameForUIClass(self.class) bundle:NSBundle.srg_identityBundle];
    SRGIdentityLoginViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.emailAddress = emailAddress;
    viewController.webserviceURL = webserviceURL;
    viewController.websiteURL = websiteURL;
    return viewController;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.emailAddressTextField.text = self.emailAddress;
    self.emailAddressTextField.placeholder = SRGIdentityLocalizedString(@"Email address", @"Email address text field placeholder");
    
    self.passwordTextField.placeholder = SRGIdentityLocalizedString(@"Password", @"Password text field placeholder");
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.movingFromParentViewController || self.beingDismissed) {
        [self.loginRequest cancel];
    }
}

#pragma mark Actions

- (IBAction)login:(id)sender
{
    NSString *emailAddress = self.emailAddressTextField.text;
    if (emailAddress.length == 0) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:SRGIdentityLocalizedString(@"Incomplete information", @"Error title for incomplete login information")
                                                                                 message:SRGIdentityLocalizedString(@"An email address is mandatory", @"Error description when no email address has been provided")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss button label") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    NSString *password = self.passwordTextField.text;
    if (password.length == 0) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:SRGIdentityLocalizedString(@"Incomplete information", @"Error title for incomplete login information")
                                                                                 message:SRGIdentityLocalizedString(@"An password is mandatory", @"Error description when no password has been provided")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss button label") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    NSURL *URL = [self.webserviceURL URLByAppendingPathComponent:@"v1/login"];
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"POST";
    [URLRequest setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    NSString *encodedEmailAddress = [emailAddress stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    NSString *encodedPassword = [password stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    
    NSString *HTTPBodyString = [NSString stringWithFormat:@"login_email=%@&login_password=%@", encodedEmailAddress, encodedPassword];
    NSData *HTTPBody = [HTTPBodyString dataUsingEncoding:NSUTF8StringEncoding];
    [URLRequest setValue:@(HTTPBody.length).stringValue forHTTPHeaderField:@"Content-Length"];
    URLRequest.HTTPBody = HTTPBody;
    
    SRGRequest *loginRequest = [SRGRequest dataRequestWithURLRequest:URLRequest session:NSURLSession.sharedSession completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        void (^showError)(NSError *) = ^(NSError *error) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", "Title of a generic error alert")
                                                                                     message:error.localizedDescription
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss button label") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alertController animated:YES completion:nil];
        };
        
        if (error) {
            showError(error);
            return;
        }
        
        NSString *token = nil;
        if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
            NSArray<NSHTTPCookie *> *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:HTTPResponse.allHeaderFields forURL:HTTPResponse.URL];
            for (NSHTTPCookie *cookie in cookies) {
                if ([cookie.name isEqualToString:@"identity.provider.sid"]) {
                    token = cookie.value;
                }
            }
        }
        
        if (! token) {
            // TODO: Proper error
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:401
                                             userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"Wrong email address or password", @"Error message displayed when incorrect user credentials have been supplied") }];
            showError(error);
            return;
        }
        
        NSLog(@"Token: %@", token);
    }];
    [loginRequest resume];
    self.loginRequest = loginRequest;
}

@end
