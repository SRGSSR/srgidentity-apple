//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentityService.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRGIdentityAccountView : UIView

/**
 *  Identity service to authentify the user.
 */
@property (nonatomic, nullable) SRGIdentityService *service;

@end

NS_ASSUME_NONNULL_END
