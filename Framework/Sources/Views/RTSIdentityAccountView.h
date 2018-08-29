//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RTSIdentityService.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CompletionBlock)(NSError * _Nullable error);

@interface RTSIdentityAccountView : UIView

/**
 *  Identity service to authentify the user.
 */
@property (nonatomic, nullable) RTSIdentityService *service;

@end

NS_ASSUME_NONNULL_END
