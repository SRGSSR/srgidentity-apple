//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAccount.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_EXPORT NSString * const SRGIdentityServiceUserLoggedInNotification;
OBJC_EXPORT NSString * const SRGIdentityServiceUserLoggedOutNotification;
OBJC_EXPORT NSString * const SRGIdentityServiceUserMetadatasUpdateNotification;

OBJC_EXPORT NSString * const SRGIdentityServiceEmailAddressKey;

typedef void (^SRGAccountCompletionBlock)(SRGAccount * _Nullable account, NSError * _Nullable error);

@interface SRGIdentityService : NSObject

/**
 *  The identity service currently set as shared instance, if any.
 */
@property (class, nonatomic, nullable) SRGIdentityService *currentIdentityService;

/**
 *  Instantiate a identity service.
 *
 *  @param serviceURL             The URL of the identifier service.
 */
- (instancetype)initWithServiceURL:(NSURL *)serviceURL accessGroup:(nullable NSString *)accessGroup NS_DESIGNATED_INITIALIZER;

/**
 *  Get account properties.
 */
- (NSURLSessionTask *)accountWithCompletionBlock:(SRGAccountCompletionBlock)completionBlock;

/**
 *  Logout the current session, if any.
 *
 */
- (void)logout;

/**
 *  The service URL.
 */
@property (nonatomic, readonly) NSURL *serviceURL;

/**
 *  The login status.
 */
@property (readonly) BOOL isLogged;

/**
 *  The logged in token, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *sessionToken;

/**
 *  The logged in email address, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *emailAddress;

/**
 *  The logged in display name, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *displayName;

/**
 *  The logged in user id, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *userId;

@end

NS_ASSUME_NONNULL_END
