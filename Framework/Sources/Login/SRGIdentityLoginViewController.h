//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(tvos(9.0)) API_UNAVAILABLE(ios)
@interface SRGIdentityLoginViewController : UIViewController

- (instancetype)initWithEmailAddress:(nullable NSString *)emailAddress;

@end

NS_ASSUME_NONNULL_END
