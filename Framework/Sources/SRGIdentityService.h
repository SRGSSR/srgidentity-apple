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
 *  `YES` iff a user is logged.
 */
@property (nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;

/**
 *  Detailed account information, if available.
 *
 *  @discussion This information might not be available yet even if a user is logged in. Always check the `loggedIn`
 *              property to determine if a user is logged in.
 */
@property (nonatomic, readonly, nullable) SRGAccount *account;

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
