//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Genders.
 */
typedef NS_ENUM(NSInteger, SRGGender) {
    /**
     *  Not specified.
     */
    SRGGenderNone = 0,
    /**
     *  Female.
     */
    SRGGenderFemale,
    /**
     *  Male.
     */
    SRGGenderMale,
    /**
     *  Other.
     */
    SRGGenderOther
};

/**
 *  Account information.
 */
@interface SRGAccount : MTLModel <MTLJSONSerializing>

/**
 *  The unique account identifier.
 */
@property (nonatomic, readonly, copy, nullable) NSString *uid;

/**
 *  The unique public account identifier.
 */
@property (nonatomic, readonly, copy, nullable) NSString *publicUid;

/**
 *  The account display name.
 */
@property (nonatomic, readonly, copy, nullable) NSString *displayName;

/**
 *  The email address associated with the account.
 */
@property (nonatomic, readonly, copy, nullable) NSString *emailAddress;

/**
 *  The user first name.
 */
@property (nonatomic, readonly, copy, nullable) NSString *firstName;

/**
 *  The user last name.
 */
@property (nonatomic, readonly, copy, nullable) NSString *lastName;

/**
 *  The user gender.
 */
@property (nonatomic, readonly) SRGGender gender;

/**
 *  The user birthdate.
 */
@property (nonatomic, readonly, nullable) NSDate *birthdate;

/**
 *  `YES` iff the account has been verified.
 */
@property (nonatomic, readonly, getter=isVerified) BOOL verified;

@end

NS_ASSUME_NONNULL_END
