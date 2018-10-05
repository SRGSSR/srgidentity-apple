//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAccount.h"

NS_ASSUME_NONNULL_BEGIN

OBJC_EXPORT NSString * const SRGIdentityServiceUserDidLoginNotification;
OBJC_EXPORT NSString * const SRGIdentityServiceUserDidLogoutNotification;
OBJC_EXPORT NSString * const SRGIdentityServiceDidUpdateAccountNotification;

OBJC_EXPORT NSString * const SRGIdentityServiceAccountKey;

@interface SRGIdentityService : NSObject

/**
 *  The identity service currently set as shared instance, if any.
 */
@property (class, nonatomic, nullable) SRGIdentityService *currentIdentityService;

/**
 *  Instantiate a identity service.
 *
 *  @param serviceURL The URL of the identifier service.
 */
- (instancetype)initWithServiceURL:(NSURL *)serviceURL NS_DESIGNATED_INITIALIZER;

/**
 *  Display the login window. If an email address is provided, it is used to fill out the form initially.
 */
- (BOOL)loginWithEmailAddress:(nullable NSString *)emailAddress;

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

// TODO: For URL scheme processing in the Safari iOS 9 workflow. Hide if possible (swizzling).
- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@end

@interface SRGIdentityService (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
