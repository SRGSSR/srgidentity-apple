//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityService.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CompletionBlock)(NSError * _Nullable error);

@interface SRGIdentityLoginView : UIView

/**
 *  Identity service to save the authentification.
 */
@property (nonatomic, nullable) SRGIdentityService *service;

/**
 *  Completion block fired when login is finished or abored.
 */
@property (nonatomic, copy, nullable) CompletionBlock completionBlock;

@end

NS_ASSUME_NONNULL_END
