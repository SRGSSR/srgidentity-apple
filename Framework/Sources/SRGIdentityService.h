//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAccount.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notification sent when a user successfully logged in.
 */
OBJC_EXPORT NSString * const SRGIdentityServiceUserDidLoginNotification;

/**
 *  Notification sent when a user cancelled a login attempt.
 */
OBJC_EXPORT NSString * const SRGIdentityServiceUserDidCancelLoginNotification;

/**
 *  Notification sent when a user logged out.
 */
OBJC_EXPORT NSString * const SRGIdentityServiceUserDidLogoutNotification;

/**
 *  Notification sent when account information has been updated. Use the keys available below to retrieve information from
 *  the notification `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGIdentityServiceDidUpdateAccountNotification;

/**
 *  Information available for `SRGIdentityServiceDidUpdateAccountNotification`.
 */
OBJC_EXPORT NSString * const SRGIdentityServiceAccountKey;              // Updated account information, as an `SRGAccount` object.
OBJC_EXPORT NSString * const SRGIdentityServicePreviousAccountKey;      // Previous account information, as an `SRGAccount` object.

/**
 *  An identity service provides a way to retrieve and store a user identity in the form of a session token. Several
 *  identity services can be instantiated within an application, though most application should only require one. For
 *  convenience, a global identity service can be set using the `currentIdentityService` class property.
 *
 *  A user must correctly supply her credentials (email address and password) to receive a session token. This procedure
 *  is initiated by calling the `-loginWithEmailAddress:` method, which opens a login / signup page. This page is opened
 *  modally in a sandboxed Safari browser, ensuring that the passord is not accessible to the host application. Tokens
 *  themselves are stored within the keychain and therefore secured by the system.
 *
 *  Identities are stored per app and are therefore not shared, and are not synchronized over iCloud. Only one user
 *  can be logged in at any time for a given service. To logout the current user, simply call `-logout`, at which point
 *  a new user can log in.
 *
 *  Note that though several services can coexist within an application, only one login process can be made at any time.
 */
@interface SRGIdentityService : NSObject

/**
 *  The identity service currently set as shared instance, if any.
 */
@property (class, nonatomic, nullable) SRGIdentityService *currentIdentityService;

/**
 *  Instantiate an identity service.
 *
 *  @param webserviceURL The URL of the identity webservices.
 *  @param websiteURL    The URL of the identity web portal.
 */
- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL NS_DESIGNATED_INITIALIZER;

/**
 *  Initiate a login procedure. Calling this method opens the service login / signup form with Safari. After successful
 *  login, an `SRGIdentityServiceUserDidLoginNotification` notification is emitted.
 *
 *  @param An optional email address, with which the form is filled initially. If not specified, the form starts empty.
 *
 *  @return `YES` if the form could be opened. The method might return `NO` if another attempt is already being made
 *          or if a user is already logged in.
 */
- (BOOL)loginWithEmailAddress:(nullable NSString *)emailAddress;

/**
 *  Logout the current user, if any.
 *
 *  @return `YES` if a user was logged out. If no user was logged in before calling this method, `NO` is returned.
 */
- (BOOL)logout;

/**
 *  The identity provider URL.
 */
@property (nonatomic, readonly) NSURL *providerURL;

/**
 *  `YES` iff a user is logged.
 */
@property (nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;

/**
 *  The email address (username) of the logged in user, if available.
 *
 *  @discussion This property must be used for informative purposes. If you want to find out whether a user is logged
 *              in, check the `loggedIn` property instead.
 */
@property (nonatomic, readonly, copy, nullable) NSString *emailAddress;

/**
 *  Detailed account information, if available.
 *
 *  @discussion This property must be used for informative purposes. If you want to find out whether a user is logged
 *              in, check the `loggedIn` property instead.
 */
@property (nonatomic, readonly, copy, nullable) SRGAccount *account;

/**
 *  The session token which has been retrieved, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *sessionToken;

@end

@interface SRGIdentityService (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
