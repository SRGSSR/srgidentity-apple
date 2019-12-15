//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityLoginViewController.h"

#import "NSBundle+SRGIdentity.h"

#import <SRGAppearance/SRGAppearance.h>
#import <SRGNetwork/SRGNetwork.h>

@interface SRGIdentityLoginViewController ()

@property (nonatomic, copy) NSString *emailAddress;
@property (nonatomic) NSURL *webserviceURL;
@property (nonatomic) NSURL *websiteURL;

@property (nonatomic, copy) void (^tokenBlock)(NSString *sessionToken);
@property (nonatomic, copy) void (^dismissalBlock)(void);

@property (nonatomic, weak) IBOutlet UITextField *emailAddressTextField;
@property (nonatomic, weak) IBOutlet UITextField *passwordTextField;
@property (nonatomic, weak) IBOutlet UIButton *loginButton;

@property (nonatomic, weak) IBOutlet UILabel *instructionsLabel;
@property (nonatomic, weak) IBOutlet UILabel *linkLabel;

@property (nonatomic, weak) SRGRequest *loginRequest;

@end

@implementation SRGIdentityLoginViewController

#pragma mark Object lifecycle

- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL
                           websiteURL:(NSURL *)websiteURL
                         emailAddress:(NSString *)emailAddress
                           tokenBlock:(void (^)(NSString * _Nonnull))tokenBlock
                       dismissalBlock:(void (^)(void))dismissalBlock
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:SRGIdentityResourceNameForUIClass(self.class) bundle:NSBundle.srg_identityBundle];
    SRGIdentityLoginViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.emailAddress = emailAddress;
    viewController.webserviceURL = webserviceURL;
    viewController.websiteURL = websiteURL;
    viewController.tokenBlock = tokenBlock;
    viewController.dismissalBlock = dismissalBlock;
    return viewController;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.emailAddressTextField.text = self.emailAddress;
    self.emailAddressTextField.placeholder = SRGIdentityLocalizedString(@"Email address", @"Email address text field placeholder on Apple TV");
    self.emailAddressTextField.font = [UIFont srg_regularFontWithSize:42.f];
    
    self.passwordTextField.placeholder = SRGIdentityLocalizedString(@"Password", @"Password text field placeholder on Apple TV");
    self.passwordTextField.font = [UIFont srg_regularFontWithSize:42.f];
    
    [self.loginButton setTitle:SRGIdentityLocalizedString(@"Sign in", @"Sign in button on Apple TV") forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont srg_regularFontWithSize:36.f];
    
    self.instructionsLabel.text = SRGIdentityLocalizedString(@"To sign up or manage your account, use a computer or mobile device and visit", @"Instructions for signup on Apple TV followed by a website url (i.e. visit a website on another device)");
    self.instructionsLabel.font = [UIFont srg_regularFontWithSize:30.f];
    
    self.linkLabel.text = self.websiteURL.absoluteString;
    self.linkLabel.font = [UIFont srg_regularFontWithSize:30.f];
    self.linkLabel.textColor = UIColor.systemBlueColor;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.movingFromParentViewController || self.beingDismissed) {
        [self.loginRequest cancel];
        self.dismissalBlock();
    }
}

#pragma mark Requests

- (SRGRequest *)loginRequestWithEmailAddress:(NSString *)emailAddress password:(NSString *)password completionHandler:(void (^)(NSString * _Nullable sessionToken, NSError * _Nullable error))completionHandler
{
    NSParameterAssert(emailAddress);
    NSParameterAssert(password);
    NSParameterAssert(completionHandler);
    
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
    
    return [SRGRequest dataRequestWithURLRequest:URLRequest session:NSURLSession.sharedSession completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        
        // Even if credentials are invalid, the request ends with a 200. Only if credentials are valid, though, we find the session token
        // in the response cookies.
        NSString *sessionToken = nil;
        if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
            NSArray<NSHTTPCookie *> *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:HTTPResponse.allHeaderFields forURL:HTTPResponse.URL];
            for (NSHTTPCookie *cookie in cookies) {
                if ([cookie.name isEqualToString:@"identity.provider.sid"]) {
                    sessionToken = cookie.value;
                }
            }
        }
        
        if (! sessionToken) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:401
                                             userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"Wrong email address or password", @"Error message displayed when incorrect user credentials have been supplied") }];
            completionHandler(nil, error);
            return;
        }
        
        completionHandler(sessionToken, nil);
    }];
}

#pragma mark Actions

- (IBAction)login:(id)sender
{
    NSString *emailAddress = self.emailAddressTextField.text;
    if (emailAddress.length == 0) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:SRGIdentityLocalizedString(@"Incomplete information", @"Error title for incomplete login information")
                                                                                 message:SRGIdentityLocalizedString(@"An email address is mandatory", @"Error description when no email address has been provided")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:SRGIdentityLocalizedString(@"Dismiss", @"Dismiss button label") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    NSString *password = self.passwordTextField.text;
    if (password.length == 0) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:SRGIdentityLocalizedString(@"Incomplete information", @"Error title for incomplete login information")
                                                                                 message:SRGIdentityLocalizedString(@"A password is mandatory", @"Error description when no password has been provided")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:SRGIdentityLocalizedString(@"Dismiss", @"Dismiss button label") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    self.loginButton.enabled = NO;
    
    SRGRequest *loginRequest = [[self loginRequestWithEmailAddress:emailAddress password:password completionHandler:^(NSString * _Nullable sessionToken, NSError * _Nullable error) {
        self.loginButton.enabled = YES;
        
        if (error) {
            if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
                return;
            }
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:SRGIdentityLocalizedString(@"Error", "Title of a generic error alert")
                                                                                     message:error.localizedDescription
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:SRGIdentityLocalizedString(@"Dismiss", @"Dismiss button label") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alertController animated:YES completion:nil];
            return;
        }
        
        self.tokenBlock(sessionToken);
    }] requestWithOptions:SRGRequestOptionCancellationErrorsEnabled];
    [loginRequest resume];
    self.loginRequest = loginRequest;
}

@end
