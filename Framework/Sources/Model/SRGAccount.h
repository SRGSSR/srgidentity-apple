//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SRGGender) {
    SRGGenderNone = 0,
    SRGGenderFemale,
    SRGGenderMale,
    SRGGenderOther
};

OBJC_EXPORT NSString *SRGDescriptionForSRGGender(SRGGender SRGGender);
OBJC_EXPORT SRGGender SRGGenderForDescription(NSString *description);

@interface SRGAccount : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy, nullable) NSString *emailAddress;
@property (nonatomic, copy, nullable) NSString *password;

@property (nonatomic, copy, nullable) NSString *firstName;
@property (nonatomic, copy, nullable) NSString *lastName;

@property (nonatomic) SRGGender SRGGender;

@property (nonatomic, nullable) NSDate *birthdate;
@property (nonatomic, copy, nullable) NSString *languageCode;

@property (nonatomic, copy, readonly, nullable) NSNumber *uid;
@property (nonatomic, copy, readonly, nullable) NSString *displayName;

/*
 *  Instance from an other account
 */
- (instancetype)initWithAccount:(SRGAccount *)account;

@end

NS_ASSUME_NONNULL_END
