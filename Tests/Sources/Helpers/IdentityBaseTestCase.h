//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGIdentity/SRGIdentity.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface IdentityBaseTestCase : XCTestCase

/**
 *  Replacement for `-expectationForNotification:object:handler:`, which suffers from stability issues.
 *  See https://github.com/SRGSSR/SRGMediaPlayer-iOS/issues/22.
 */
- (XCTestExpectation *)expectationForSingleNotification:(NSNotificationName)notificationName object:(nullable id)objectToObserve handler:(nullable XCNotificationExpectationHandler)handler;

/**
 *  Expectation fulfilled after some given time interval (in seconds), calling the optionally provided handler. Can
 *  be useful for ensuring nothing unexpected occurs during some time
 */
- (XCTestExpectation *)expectationForElapsedTimeInterval:(NSTimeInterval)timeInterval withHandler:(nullable void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END
