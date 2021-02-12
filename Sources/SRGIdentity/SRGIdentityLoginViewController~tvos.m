//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <TargetConditionals.h>

#if TARGET_OS_TV

#import "SRGIdentityLoginViewController.h"

#import "NSBundle+SRGIdentity.h"
#import "UIImage+SRGIdentity.h"

@import SRGAppearance;
@import SRGNetwork;

@interface SRGIdentityLoginViewController () <UITextFieldDelegate>

@property (nonatomic, copy) NSString *emailAddress;
@property (nonatomic) NSURL *webserviceURL;
@property (nonatomic) NSURL *websiteURL;

@property (nonatomic, copy) void (^tokenBlock)(NSString *sessionToken);
@property (nonatomic, copy) void (^dismissalBlock)(void);

@property (nonatomic, weak) UITextField *emailAddressTextField;
@property (nonatomic, weak) UITextField *passwordTextField;
@property (nonatomic, weak) UIButton *loginButton;

@property (nonatomic, weak) UILabel *instructionsLabel;
@property (nonatomic, weak) UILabel *linkLabel;

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
    SRGIdentityLoginViewController *viewController = [[SRGIdentityLoginViewController alloc] init];
    viewController.emailAddress = emailAddress;
    viewController.webserviceURL = webserviceURL;
    viewController.websiteURL = websiteURL;
    viewController.tokenBlock = tokenBlock;
    viewController.dismissalBlock = dismissalBlock;
    return viewController;
}

#pragma mark View lifecycle

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view = view;
    
    [self loadCredentialsStackViewInView:view];
    [self loadInstructionsStackViewInView:view];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.movingFromParentViewController || self.beingDismissed) {
        [self.loginRequest cancel];
        self.dismissalBlock();
    }
}

#pragma mark Focus management

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments
{
    if (self.emailAddressTextField.text.length != 0 && self.passwordTextField.text.length != 0) {
        return @[self.loginButton];
    }
    else {
        return @[];
    }
}

#pragma mark Layout helpers

- (void)loadCredentialsStackViewInView:(UIView *)view
{
    UIStackView *credentialsStackView = [[UIStackView alloc] init];
    credentialsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    credentialsStackView.axis = UILayoutConstraintAxisVertical;
    credentialsStackView.alignment = UIStackViewAlignmentCenter;
    credentialsStackView.distribution = UIStackViewDistributionFill;
    credentialsStackView.spacing = 40.f;
    [view addSubview:credentialsStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [credentialsStackView.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [credentialsStackView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        [credentialsStackView.widthAnchor constraintEqualToConstant:750.f]
    ]];
    
    [self loadServiceLogoInStackView:credentialsStackView];
    [self loadFixedSpacerWithHeight:0.f inStackView:credentialsStackView];
    [self loadEmailAddressTextFieldInStackView:credentialsStackView];
    [self loadPasswordTextFieldInStackView:credentialsStackView];
    [self loadLoginButtonInStackView:credentialsStackView];
}

- (void)loadServiceLogoInStackView:(UIStackView *)stackView
{
    UIImage *serviceLogoImage = [UIImage imageNamed:@"identity_service_logo"] ?: [UIImage srg_identityImageNamed:@"service_logo"];
    UIImageView *serviceLogoImageView = [[UIImageView alloc] initWithImage:serviceLogoImage];
    serviceLogoImageView.tintColor = UIColor.systemGrayColor;
    [stackView addArrangedSubview:serviceLogoImageView];
}

- (void)loadFixedSpacerWithHeight:(CGFloat)height inStackView:(UIStackView *)stackView
{
    // Zero height, but adds two stack spacing contributions and thus some spacing
    UIView *spacerView = [[UIView alloc] init];
    spacerView.translatesAutoresizingMaskIntoConstraints = NO;
    spacerView.backgroundColor = UIColor.clearColor;
    [stackView addArrangedSubview:spacerView];
    
    [NSLayoutConstraint activateConstraints:@[
        [spacerView.widthAnchor constraintEqualToAnchor:stackView.widthAnchor],
        [spacerView.heightAnchor constraintEqualToConstant:height]
    ]];
}

- (void)loadEmailAddressTextFieldInStackView:(UIStackView *)stackView
{
    UITextField *emailAddressTextField = [[UITextField alloc] init];
    emailAddressTextField.translatesAutoresizingMaskIntoConstraints = NO;
    emailAddressTextField.text = self.emailAddress;
    emailAddressTextField.placeholder = SRGIdentityLocalizedString(@"Email address", @"Email address text field placeholder on Apple TV");
    emailAddressTextField.font = [UIFont srg_regularFontWithSize:42.f];
    emailAddressTextField.textContentType = UITextContentTypeEmailAddress;
    emailAddressTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [stackView addArrangedSubview:emailAddressTextField];
    self.emailAddressTextField = emailAddressTextField;
    
    [NSLayoutConstraint activateConstraints:@[
        [emailAddressTextField.widthAnchor constraintEqualToAnchor:stackView.widthAnchor],
        [emailAddressTextField.heightAnchor constraintEqualToConstant:70.f]
    ]];
}

- (void)loadPasswordTextFieldInStackView:(UIStackView *)stackView
{
    UITextField *passwordTextField = [[UITextField alloc] init];
    passwordTextField.translatesAutoresizingMaskIntoConstraints = NO;
    passwordTextField.delegate = self;
    passwordTextField.placeholder = SRGIdentityLocalizedString(@"Password", @"Password text field placeholder on Apple TV");
    passwordTextField.font = [UIFont srg_regularFontWithSize:42.f];
    passwordTextField.textContentType = UITextContentTypePassword;
    passwordTextField.secureTextEntry = YES;
    passwordTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [stackView addArrangedSubview:passwordTextField];
    self.passwordTextField = passwordTextField;
    
    [NSLayoutConstraint activateConstraints:@[
        [passwordTextField.widthAnchor constraintEqualToAnchor:stackView.widthAnchor],
        [passwordTextField.heightAnchor constraintEqualToConstant:70.f]
    ]];
}

- (void)loadLoginButtonInStackView:(UIStackView *)stackView
{
    UIButton *loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [loginButton setTitle:SRGIdentityLocalizedString(@"Sign in", @"Sign in button on Apple TV") forState:UIControlStateNormal];
    loginButton.titleLabel.font = [UIFont srg_regularFontWithSize:36.f];
    [loginButton addTarget:self action:@selector(login:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [stackView addArrangedSubview:loginButton];
    self.loginButton = loginButton;
}

- (void)loadInstructionsStackViewInView:(UIView *)view
{
    UIStackView *instructionsStackView = [[UIStackView alloc] init];
    instructionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    instructionsStackView.axis = UILayoutConstraintAxisVertical;
    instructionsStackView.alignment = UIStackViewAlignmentFill;
    instructionsStackView.distribution = UIStackViewDistributionFill;
    [view addSubview:instructionsStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [instructionsStackView.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [instructionsStackView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-38.f],
        [instructionsStackView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:40.f],
        [instructionsStackView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-40.f],
    ]];
    
    UILabel *instructionsLabel = [[UILabel alloc] init];
    instructionsLabel.textAlignment = NSTextAlignmentCenter;
    instructionsLabel.text = SRGIdentityLocalizedString(@"To sign up or manage your account, use a computer or mobile device and visit", @"Instructions for signup on Apple TV followed by a website url (i.e. visit a website on another device)");
    instructionsLabel.font = [UIFont srg_regularFontWithSize:30.f];
    [instructionsStackView addArrangedSubview:instructionsLabel];
    self.instructionsLabel = instructionsLabel;
    
    UILabel *linkLabel = [[UILabel alloc] init];
    linkLabel.textAlignment = NSTextAlignmentCenter;
    linkLabel.text = self.websiteURL.absoluteString;
    linkLabel.font = [UIFont srg_regularFontWithSize:30.f];
    linkLabel.textColor = UIColor.systemBlueColor;
    [instructionsStackView addArrangedSubview:linkLabel];
    self.linkLabel = linkLabel;
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

#pragma mark UITextFieldDelegate protocol

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

#pragma mark Actions

- (void)login:(id)sender
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

#endif
