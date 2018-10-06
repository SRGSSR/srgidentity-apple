//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAuthentificationController.h"

#import "NSBundle+SRGIdentity.h"
#import "SRGIdentityError.h"

#import <SafariServices/SafariServices.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <libextobjc/libextobjc.h>

#import "SRGAuthentificationDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRGAuthentificationController () <SFSafariViewControllerDelegate>

@property(nonatomic, weak) UIViewController *presentingViewController;
@property(nonatomic, nullable) SRGAuthentificationRequest *request;

@property(nonatomic, nullable, weak) id<SRGAuthentificationDelegate> delegate;

@property(nonatomic, getter=isInProgress) BOOL inProgress;

@property(nonatomic, nullable, weak) SFSafariViewController *safariViewController;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
@property(nonatomic, nullable) SFAuthenticationSession *authenticationSession;
@property(nonatomic, nullable) ASWebAuthenticationSession *webAuthenticationSession;
#pragma clang diagnostic pop
@end

@implementation SRGAuthentificationController

- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController {
    if ([super init]) {
        self.presentingViewController = presentingViewController;
    }
    return self;
}

- (BOOL)presentControllerWithRequest:(SRGAuthentificationRequest *)request
                            delegate:(id <SRGAuthentificationDelegate>)delegate {
    if (self.inProgress) {
        // TODO: Handle errors as authorization is already in progress.
        return NO;
    }
    
    self.inProgress = YES;
    self.delegate = delegate;
    
    BOOL openedSafari = NO;
    
    // iOS 12 and later, use ASWebAuthenticationSession
    if (@available(iOS 12.0, *)) {
        @weakify(self)
        ASWebAuthenticationSession *webAuthenticationSession = [[ASWebAuthenticationSession alloc] initWithURL:request.URL
                                                                                             callbackURLScheme:request.redirectURL.scheme
                                                                                             completionHandler:^(NSURL * _Nullable callbackURL,
                                                                                                                 NSError * _Nullable error) {
                                                                                                 @strongify(self)
                                                                                                 
                                                                                                 self.webAuthenticationSession = nil;
                                                                                                 if (callbackURL) {
                                                                                                     [self.delegate resumeAuthentificationWithURL:callbackURL];
                                                                                                 }
                                                                                                 else {
                                                                                                     NSError *safariError = [NSError errorWithDomain:SRGIdentityErrorDomain
                                                                                                                                                code:SRGAuthentificationCanceled
                                                                                                                                            userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"Authentification canceled.", @"Error message returned when the user or the app canceled the authentification process.") }];
                                                                                                     [self.delegate failAuthentificationWithError:safariError];
                                                                                                 }
                                                                                             }];
        self.webAuthenticationSession = webAuthenticationSession;
        openedSafari = [webAuthenticationSession start];
    }
    // iOS 11, use SFAuthenticationSession
    else if (@available(iOS 11.0, *)) {
        @weakify(self)
        SFAuthenticationSession *authenticationSession = [[SFAuthenticationSession alloc] initWithURL:request.URL
                                                                                    callbackURLScheme:request.redirectURL.scheme
                                                                                    completionHandler:^(NSURL * _Nullable callbackURL,
                                                                                                        NSError * _Nullable error) {
                                                                                        @strongify(self)
                                                                                        
                                                                                        self.authenticationSession = nil;
                                                                                        if (callbackURL) {
                                                                                            [self.delegate resumeAuthentificationWithURL:callbackURL];
                                                                                        }
                                                                                        else {
                                                                                            NSError *safariError = [NSError errorWithDomain:SRGIdentityErrorDomain
                                                                                                                                       code:SRGAuthentificationCanceled
                                                                                                                                   userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"Authentification canceled.", @"Error message returned when the user or the app canceled the authentification process.") }];
                                                                                            [self.delegate failAuthentificationWithError:safariError];
                                                                                        }
                                                                                    }];
        self.authenticationSession = authenticationSession;
        openedSafari = [authenticationSession start];
    }
    // iOS 9 and 10, use SFSafariViewController
    else {
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:request.URL entersReaderIfAvailable:NO];
        
        safariViewController.delegate = self;
        self.safariViewController = safariViewController;
        [self.presentingViewController presentViewController:safariViewController animated:YES completion:nil];
        openedSafari = YES;
    }
    
    if (! openedSafari) {
        [self cleanUp];
        NSError *safariError = [NSError errorWithDomain:SRGIdentityErrorDomain
                                                   code:SRGAuthentificationStartFailed
                                               userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"Unable to open Safari", @"Error message returned when the authentification process can't start.") }];
        [delegate failAuthentificationWithError:safariError];
    }
    else {
        self.request = request;
    }
    return openedSafari;
}

- (void)dismissExternalUserAgentAnimated:(BOOL)animated completion:(void (^)(void))completion {
    if (! self.inProgress) {
        // Ignore this call if there is no authorization flow in progress.
        return;
    }
    
    SFSafariViewController *safariViewController = self.safariViewController;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    SFAuthenticationSession *authenticationSession = self.authenticationSession;
    ASWebAuthenticationSession *webAuthenticationSession = self.webAuthenticationSession;
#pragma clang diagnostic pop
    
    [self cleanUp];
    
    if (@available(iOS 12.0, *)) {
        [webAuthenticationSession cancel];
        if (completion) completion();
    }
    else if (@available(iOS 11.0, *)) {
        [authenticationSession cancel];
        if (completion) completion();
    }
    else {
        if (safariViewController) {
            [safariViewController dismissViewControllerAnimated:YES completion:completion];
        }
        else if (completion) completion();
    }
}

- (void)cleanUp {
    // The weak references to |_safariVC| and |_session| are set to nil to avoid accidentally using
    // them while not in an authentification flow.
    self.safariViewController = nil;
    self.authenticationSession = nil;
    self.delegate = nil;
    self.inProgress = NO;
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    if (controller != self.safariViewController) {
        // Ignore this call if the safari view controller do not match.
        return;
    }
    if (! self.inProgress) {
        // Ignore this call if there is no authorization flow in progress.
        return;
    }
    id<SRGAuthentificationDelegate> delegate = self.delegate;
    [self cleanUp];
    NSError *error = [NSError errorWithDomain:SRGIdentityErrorDomain
                                         code:SRGAuthentificationCanceled
                                     userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"Authentification canceled.", @"Error message returned when the user or the app canceled the authentification process.") }];
    [delegate failAuthentificationWithError:error];
}

@end

NS_ASSUME_NONNULL_END
