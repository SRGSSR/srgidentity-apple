//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAccount.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Available login methods.
 */
typedef NS_ENUM(NSInteger, SRGIdentityLoginMethod) {
    /**
     *  The default recommended method.
     */
    SRGIdentityLoginMethodDefault = 0,
    /**
     *  Login is displayed in a dedicated Safari web view.
     */
    SRGIdentityLoginMethodSafari = SRGIdentityLoginMethodDefault,
    /**
     *  Use an authentication session when available (iOS 11 and 12 only). User credentials can be shared between your
     *  app and Safari. This makes it possible for a user to automatically authenticate in another app associated with
     *  the same identity provider (if credentials are still available). Note that a system alert will inform the user
     *  about credentials sharing first.
     */
    SRGIdentityLoginMethodAuthenticationSession
};

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
 *  Information available for `SRGIdentityServiceUserDidLogoutNotification`.
 */
OBJC_EXPORT NSString * const SRGIdentityServiceUnauthorizedKey;         // Key to an `NSNumber` wrapping a boolean, set to `YES` iff the user was unauthorized.
OBJC_EXPORT NSString * const SRGIdentityServiceDeletedKey;              // Key to an `NSNumber` wrapping a boolean, set to `YES` iff the user deleted his/her account.

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
 *  Instantiate an identity service. A login method can be selected.
 *
 *  @param webserviceURL The URL of the identity webservices.
 *  @param websiteURL    The URL of the identity web portal.
 *  @param loginMethod   The login method to use if possible.
 */
- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL loginMethod:(SRGIdentityLoginMethod)loginMethod NS_DESIGNATED_INITIALIZER;

/**
 *  Same as `-initWithWebserviceURL:websiteURL:loginMethod:`, using the default recommended login method.
 */
- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL;

/**
 *  Initiate a login procedure. Calling this method opens the service login / signup form with Safari. After successful
 *  login, an `SRGIdentityServiceUserDidLoginNotification` notification is emitted.
 *
 *  @param emailAddress An optional email address, with which the form is filled initially. If not specified, the form starts empty.
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
@property (nonatomic, readonly, nullable) SRGAccount *account;

/**
 *  The session token which has been retrieved, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *sessionToken;

/**
 *  Show the account view. The account view has a similar look & feel as the login view, and cannot be customized
 *  through `UIAppearance`.
 *
 *  @discussion This method must be called from the main thread. If no user is logged in, calling the method does nothing.
 *              Note that only one account view can be presented at any given time.
 */
- (void)showAccountView API_UNAVAILABLE(tvos);

/**
 *  If an unauthorized error is received when using a third-party service on behalf of the current identity, call this
 *  method to ask the identity service to check whether the apparent situation is confirmed. The service will in all
 *  cases update account information to check whether the reported unauthorization is actually true.
 *
 *  A user is confirmed to be unauthorized is automatically logged out. The `SRGIdentityServiceUserDidLogoutNotification`
 *  notification is sent with `SRGIdentityServiceUnauthorizedKey` set to `@YES` in its `userInfo` dictionary.
 *
 *  If the user is still authorized, though, only account information gets updated, but no logout is made. This means that
 *  the third-party service for which the issue was reported is wrong, probably because it could not correctly validate the
 *  session token.
 *
 *  @discussion The method does nothing if called while a unauthorization check is already being made, or if no user
 *              is currently logged in.
 */
- (void)reportUnauthorization;

@end

@interface SRGIdentityService (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
