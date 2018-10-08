//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAccount.h"
#import "SRGAuthenticationDelegate.h"

#import <SRGNetwork/SRGNetwork.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_EXPORT NSString * const SRGIdentityServiceUserDidLoginNotification;
OBJC_EXPORT NSString * const SRGIdentityServiceUserDidLogoutNotification;
OBJC_EXPORT NSString * const SRGIdentityServiceDidUpdateAccountNotification;

OBJC_EXPORT NSString * const SRGIdentityServiceAccountKey;

typedef void (^SRGAuthenticationCompletionBlock)(NSError * _Nullable error);

@interface SRGIdentityService : NSObject <SRGAuthenticationDelegate>

/**
 *  The identity service currently set as shared instance, if any.
 */
@property (class, nonatomic, nullable) SRGIdentityService *currentIdentityService;

/**
 *  Instantiate a identity service.
 *
 *  @param serviceURL The URL of the identifier service.
 */
- (instancetype)initWithServiceURL:(NSURL *)serviceURL accessGroup:(nullable NSString *)accessGroup NS_DESIGNATED_INITIALIZER;

- (BOOL)presentauthenticationViewControllerFromViewController:(UIViewController *)presentingViewController
                                                completionBlock:(nullable SRGAuthenticationCompletionBlock)completionBlock;

/**
 *  Logout the current user, if any.
 */
- (void)logout;

/**
 *  The service URL.
 */
@property (nonatomic, readonly) NSURL *serviceURL;

/**
 *  The logged in email address, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *emailAddress;

/**
 *  Detailed account information, if available.
 */
@property (nonatomic, readonly, nullable) SRGAccount *account;

/**
 *  The login status.
 */
@property (nonatomic, readonly, getter=isLogged) BOOL logged;

/**
 *  The logged in token, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *sessionToken;

@end

@interface SRGIdentityService (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
