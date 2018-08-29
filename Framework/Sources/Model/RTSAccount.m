//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RTSAccount.h"

#import <libextobjc/libextobjc.h>

static NSDictionary<NSNumber *, NSString *> *RTSGenderDescriptions(void)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary<NSNumber *, NSString *> *s_RTSGenderDescriptions;
    dispatch_once(&s_onceToken, ^{
        s_RTSGenderDescriptions = @{ @(RTSGenderNone) : NSLocalizedString(@"Not specified", @"Unspecified RTSGender"),
                                  @(RTSGenderFemale) : NSLocalizedString(@"Female", "Female RTSGender"),
                                  @(RTSGenderMale) : NSLocalizedString(@"Male", @"Male RTSGender"),
                                  @(RTSGenderOther) : NSLocalizedString(@"Other", @"Other RTSGender") };
    });
    return s_RTSGenderDescriptions;
}

NSString *RTSDescriptionForRTSGender(RTSGender RTSGender)
{
    NSDictionary<NSNumber *, NSString *> *genderDescriptions = RTSGenderDescriptions();
    return genderDescriptions[@(RTSGender)];
}

RTSGender RTSGenderForDescription(NSString *description)
{
    NSDictionary<NSNumber *, NSString *> *genderDescriptions = RTSGenderDescriptions();
    return [genderDescriptions allKeysForObject:description].firstObject.integerValue;
}

@interface RTSAccount ()

@property (nonatomic, copy) NSNumber *uid;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, getter=isValidated) BOOL validated;

@end

@implementation RTSAccount

- (instancetype)initWithAccount:(RTSAccount *)account
{
    self = [super init];
    if (self) {
        [account.dictionaryValue enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if (! [obj isKindOfClass:NSNull.class]) {
                [self setValue:obj forKey:key];
            }
        }];
    }
    return self;
}

#pragma mark MTLJSONSerializing protocol

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    static NSDictionary *s_mapping;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_mapping = @{ @keypath(RTSAccount.new, emailAddress) : @"email",
                       @keypath(RTSAccount.new, password) : @"password",
                       @keypath(RTSAccount.new, firstName) : @"firstname",
                       @keypath(RTSAccount.new, lastName) : @"lastname",
                       @keypath(RTSAccount.new, RTSGender) : @"RTSGender",
                       @keypath(RTSAccount.new, birthdate) : @"date_of_birth",
                       @keypath(RTSAccount.new, languageCode) : @"language",
                       @keypath(RTSAccount.new, uid) : @"id",
                       @keypath(RTSAccount.new, displayName) : @"display_name" };
    });
    return s_mapping;
}

#pragma mark Overrides

- (BOOL)validate:(NSError **)pError
{
    self.validated = YES;
    BOOL result = [super validate:pError];
    self.validated = NO;
    return result;
}

#pragma mark Transformers

+ (NSValueTransformer *)RTSGenderJSONTransformer
{
    static NSValueTransformer *s_transformer;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_transformer = [NSValueTransformer mtl_valueMappingTransformerWithDictionary:@{ @"other" : @(RTSGenderOther),
                                                                                         @"female" : @(RTSGenderFemale),
                                                                                         @"male" : @(RTSGenderMale) }
                                                                         defaultValue:@(RTSGenderNone)
                                                                  reverseDefaultValue:nil];
    });
    return s_transformer;
}

+ (NSValueTransformer *)birthdateJSONTransformer
{
    static NSValueTransformer *s_transformer;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        
        s_transformer = [MTLValueTransformer transformerUsingForwardBlock:^id(NSString *dateString, BOOL *success, NSError *__autoreleasing *error) {
            return [dateFormatter dateFromString:dateString];
        } reverseBlock:^id(NSDate *date, BOOL *success, NSError *__autoreleasing *error) {
            return [dateFormatter stringFromDate:date];
        }];
    });
    return s_transformer;
}

@end
