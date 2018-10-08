//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAccount.h"

#import <libextobjc/libextobjc.h>

NSString *SRGDescriptionForGender(SRGGender SRGGender)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary<NSNumber *, NSString *> *s_descriptions;
    dispatch_once(&s_onceToken, ^{
        s_descriptions = @{ @(SRGGenderNone) : NSLocalizedString(@"Not specified", @"Unspecified gender"),
                            @(SRGGenderFemale) : NSLocalizedString(@"Female", "Female"),
                            @(SRGGenderMale) : NSLocalizedString(@"Male", @"Male"),
                            @(SRGGenderOther) : NSLocalizedString(@"Other", @"Other gender") };
    });
    return s_descriptions[@(SRGGender)];
}

@interface SRGAccount ()

@property (nonatomic, copy) NSNumber *uid;
@property (nonatomic, copy) NSString *displayName;

@end

@implementation SRGAccount

#pragma mark MTLJSONSerializing protocol

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    static NSDictionary *s_mapping;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_mapping = @{ @keypath(SRGAccount.new, emailAddress) : @"email",
                       @keypath(SRGAccount.new, password) : @"password",
                       @keypath(SRGAccount.new, firstName) : @"firstname",
                       @keypath(SRGAccount.new, lastName) : @"lastname",
                       @keypath(SRGAccount.new, SRGGender) : @"SRGGender",
                       @keypath(SRGAccount.new, birthdate) : @"date_of_birth",
                       @keypath(SRGAccount.new, languageCode) : @"language",
                       @keypath(SRGAccount.new, uid) : @"id",
                       @keypath(SRGAccount.new, displayName) : @"display_name" };
    });
    return s_mapping;
}

#pragma mark Transformers

+ (NSValueTransformer *)SRGGenderJSONTransformer
{
    static NSValueTransformer *s_transformer;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_transformer = [NSValueTransformer mtl_valueMappingTransformerWithDictionary:@{ @"other" : @(SRGGenderOther),
                                                                                         @"female" : @(SRGGenderFemale),
                                                                                         @"male" : @(SRGGenderMale) }
                                                                         defaultValue:@(SRGGenderNone)
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
