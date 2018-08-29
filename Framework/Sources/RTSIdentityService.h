//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RTSAccount.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_EXPORT NSString * const RTSIdentityServiceUserLoggedInNotification;
OBJC_EXPORT NSString * const RTSIdentityServiceUserLoggedOutNotification;
OBJC_EXPORT NSString * const RTSIdentityServiceUserMetadatasUpdateNotification;

OBJC_EXPORT NSString * const RTSIdentityServiceEmailAddressKey;

typedef void (^RTSAccountCompletionBlock)(RTSAccount * _Nullable account, NSError * _Nullable error);

@interface RTSIdentityService : NSObject

/**
 *  The identity service currently set as shared instance, if any.
 *
 *  @see `-setCurrentIdentityService:`.
 */
+ (nullable RTSIdentityService *)currentIdentityService;

/**
 *  Set an identity service as shared instance for convenient retrieval via `-currentIdentityService`.
 *
 *  @return The previously installed shared instance, if any.
 */
+ (nullable RTSIdentityService *)setCurrentIdentityService:(RTSIdentityService *)currentIdentityService;

/**
 *  Instantiate a identity service.
 *
 *  @param serviceURL             The URL of the identifier service.
 */
- (instancetype)initWithServiceURL:(NSURL *)serviceURL NS_DESIGNATED_INITIALIZER;

/**
 *  Get account properties.
 */
- (NSURLSessionTask *)accountWithCompletionBlock:(RTSAccountCompletionBlock)completionBlock;

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

/**
 *  The logged in token, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *token;

@end

NS_ASSUME_NONNULL_END
