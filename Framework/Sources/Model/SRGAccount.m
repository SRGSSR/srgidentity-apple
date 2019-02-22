//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGAccount.h"

#import <libextobjc/libextobjc.h>

@interface SRGAccount ()

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *publicUid;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *emailAddress;
@property (nonatomic, copy) NSString *firstName;
@property (nonatomic, copy) NSString *lastName;
@property (nonatomic) SRGGender gender;
@property (nonatomic) NSDate *birthdate;
@property (nonatomic, getter=isVerified) BOOL verified;

@end

@implementation SRGAccount

#pragma mark MTLJSONSerializing protocol

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    static NSDictionary *s_mapping;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_mapping = @{ @keypath(SRGAccount.new, uid) : @"id",
                       @keypath(SRGAccount.new, publicUid) : @"publicUid",
                       @keypath(SRGAccount.new, displayName) : @"displayName",
                       @keypath(SRGAccount.new, emailAddress) : @"login",
                       @keypath(SRGAccount.new, firstName) : @"firstName",
                       @keypath(SRGAccount.new, lastName) : @"lastName",
                       @keypath(SRGAccount.new, gender) : @"gender",
                       @keypath(SRGAccount.new, birthdate) : @"birthdate",
                       @keypath(SRGAccount.new, verified) : @"verified" };
    });
    return s_mapping;
}

#pragma mark Transformers

+ (NSValueTransformer *)genderJSONTransformer
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

#pragma mark Equality

- (BOOL)isEqual:(id)object
{
    if (! [object isKindOfClass:self.class]) {
        return NO;
    }
    
    SRGAccount *otherAccount = object;
    return [self.uid isEqualToString:otherAccount.uid];
}

- (NSUInteger)hash
{
    return self.uid.hash;
}

@end
