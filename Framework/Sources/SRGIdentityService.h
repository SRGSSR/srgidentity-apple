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
 *  Notification sent when a user logged out.
 */
OBJC_EXPORT NSString * const SRGIdentityServiceUserDidLogoutNotification;
OBJC_EXPORT NSString * const SRGIdentityServiceDidUpdateAccountNotification;

OBJC_EXPORT NSString * const SRGIdentityServiceAccountKey;

/**
 *  An identity service provides a way to retrieve a user identity for a given service. Peach (http://peach.ebu.io/)
 *  is the only supported service provider at the moment. Several identity services can be instantiated within
 *  an application, though most application should only require one. A global identity service can be set using
 *  the `currentIdentityService` class property.
 *
 *  A login procedure is initiated by calling the `-loginWithEmailAddress:` method (a user account is bound to an
 *  email address). This opens the login / signup page in a safe Safari remote process, ensuring that user credentials
 *  are not leaked. Once the user has successfully logged in, a token is received by the application, which securely
 *  stores it in the keychain for later retrieval.
 *
 *  Tokens are stored per app and are therefore not shared. They are also not synchronized over iCloud. Only one
 *  user can be logged in at any time. To logout the current user, simply call `-logout`, at which point a new
 *  user can log in. When a user is logged out, associated keychain information is discarded.
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
 *  @param serviceURL The URL of the identity service.
 */
- (instancetype)initWithServiceURL:(NSURL *)serviceURL NS_DESIGNATED_INITIALIZER;

/**
 *  Initiate a login procedure. Calling this method opens the service login / signup form with Safari. After successful
 *  login in, an `SRGIdentityServiceUserDidLoginNotification` is emitted.
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
 *  The service URL.
 */
@property (nonatomic, readonly) NSURL *serviceURL;

/**
 *  `YES` iff a user is logged.
 */
@property (nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;

/**
 *  The email address (username) of the logged in user, if available.
 *
 *  @discussion Always check the `loggedIn` property to determine if a user is logged in, as this property might not
 *              be immediately available after login.
 */
@property (nonatomic, readonly, copy, nullable) NSString *emailAddress;

/**
 *  Detailed account information, if available.
 *
 *  @discussion This piece of information might not be available yet, even if a user is logged in. Always check the
 *              `loggedIn` property to determine if a user is logged in.
 */
@property (nonatomic, readonly, nullable) SRGAccount *account;

/**
 *  The token .
 */
@property (nonatomic, readonly, copy, nullable) NSString *sessionToken;

// TODO: For URL scheme processing in the Safari iOS 9 workflow. Hide if possible (swizzling).
- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@end

@interface SRGIdentityService (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
