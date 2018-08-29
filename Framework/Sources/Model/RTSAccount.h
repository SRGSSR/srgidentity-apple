//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, RTSGender) {
    RTSGenderEnumBegin = 0,
    RTSGenderNone = RTSGenderEnumBegin,
    RTSGenderFemale,
    RTSGenderMale,
    RTSGenderOther,
    RTSGenderEnumEnd,
    RTSGenderEnumSize = RTSGenderEnumEnd - RTSGenderEnumBegin
};

OBJC_EXPORT NSString *RTSDescriptionForRTSGender(RTSGender RTSGender);
OBJC_EXPORT RTSGender RTSGenderForDescription(NSString *description);

@interface RTSAccount : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy, nullable) NSString *emailAddress;
@property (nonatomic, copy, nullable) NSString *password;

@property (nonatomic, copy, nullable) NSString *firstName;
@property (nonatomic, copy, nullable) NSString *lastName;

@property (nonatomic) RTSGender RTSGender;

@property (nonatomic, nullable) NSDate *birthdate;
@property (nonatomic, copy, nullable) NSString *languageCode;

@property (nonatomic, copy, readonly, nullable) NSNumber *uid;
@property (nonatomic, copy, readonly, nullable) NSString *displayName;

/*
 *  Instance from an other account
 */
- (instancetype)initWithAccount:(RTSAccount *)account;

@end

NS_ASSUME_NONNULL_END
