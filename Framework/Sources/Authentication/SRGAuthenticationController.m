//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAuthenticationController.h"

#import "NSBundle+SRGIdentity.h"
#import "SRGIdentityError.h"

#import <SafariServices/SafariServices.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <libextobjc/libextobjc.h>

#import "SRGAuthenticationDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRGAuthenticationController () <SFSafariViewControllerDelegate>

@property(nonatomic, weak) UIViewController *presentingViewController;
@property(nonatomic, nullable) SRGAuthenticationRequest *request;

@property(nonatomic, nullable, weak) id<SRGAuthenticationDelegate> delegate;

@property(nonatomic, getter=isInProgress) BOOL inProgress;

@property(nonatomic, nullable, weak) SFSafariViewController *safariViewController;

@property(nonatomic, nullable) id authenticationSession /* ASWebAuthenticationSession or SFAuthenticationSession */;

@end

@implementation SRGAuthenticationController

- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController
{
    if (self = [super init]) {
        self.presentingViewController = presentingViewController;
    }
    return self;
}

- (BOOL)presentControllerWithRequest:(SRGAuthenticationRequest *)request
                            delegate:(id <SRGAuthenticationDelegate>)delegate
{
    if (self.inProgress) {
        // TODO: Handle errors as authorization is already in progress.
        return NO;
    }
    
    self.inProgress = YES;
    self.delegate = delegate;
    
    BOOL openedSafari = NO;
    
    void (^completionHandler)(NSURL * _Nullable, NSError * _Nullable) = ^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
        self.authenticationSession = nil;
        
        if (callbackURL) {
            [self.delegate resumeAuthenticationWithURL:callbackURL];
        }
        else {
            NSError *safariError = [NSError errorWithDomain:SRGIdentityErrorDomain
                                                       code:SRGAuthenticationCancelled
                                                   userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"authentication cancelled.", @"Error message returned when the user or the app cancelled the authentication process.") }];
            [self.delegate failAuthenticationWithError:safariError];
        }
    };
    
    // iOS 12 and later, use ASWebAuthenticationSession
    if (@available(iOS 12.0, *)) {
        ASWebAuthenticationSession *authenticationSession = [[ASWebAuthenticationSession alloc] initWithURL:request.URL
                                                                                          callbackURLScheme:request.redirectURL.scheme
                                                                                          completionHandler:completionHandler];
        self.authenticationSession = authenticationSession;
        openedSafari = [authenticationSession start];
    }
    // iOS 11, use SFAuthenticationSession
    else if (@available(iOS 11.0, *)) {
        SFAuthenticationSession *authenticationSession = [[SFAuthenticationSession alloc] initWithURL:request.URL
                                                                                    callbackURLScheme:request.redirectURL.scheme
                                                                                    completionHandler:completionHandler];
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
                                                   code:SRGAuthenticationStartFailed
                                               userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"Unable to open Safari", @"Error message returned when the authentication process can't start.") }];
        [delegate failAuthenticationWithError:safariError];
    }
    else {
        self.request = request;
    }
    return openedSafari;
}

- (void)dismissExternalUserAgentAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    if (! self.inProgress) {
        // Ignore this call if there is no authorization flow in progress.
        return;
    }
    
    [self cleanUp];
    
    if (self.authenticationSession) {
        [self.authenticationSession cancel];
        completion ? completion() : nil;
    }
    else {
        if (self.safariViewController) {
            [self.safariViewController dismissViewControllerAnimated:YES completion:completion];
        }
        else if (completion) {
            completion();
        }
    }
}

- (void)cleanUp
{
    // The weak references to |_safariVC| and |_session| are set to nil to avoid accidentally using
    // them while not in an authentication flow.
    self.safariViewController = nil;
    
    if (@available(iOS 11, *)) {
        self.authenticationSession = nil;
    }
        
    self.delegate = nil;
    self.inProgress = NO;
}

#pragma mark SFSafariViewControllerDelegate protocol

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
    id<SRGAuthenticationDelegate> delegate = self.delegate;
    [self cleanUp];
    NSError *error = [NSError errorWithDomain:SRGIdentityErrorDomain
                                         code:SRGAuthenticationCancelled
                                     userInfo:@{ NSLocalizedDescriptionKey : SRGIdentityLocalizedString(@"authentication cancelled.", @"Error message returned when the user or the app cancelled the authentication process.") }];
    [delegate failAuthenticationWithError:error];
}

@end

NS_ASSUME_NONNULL_END
