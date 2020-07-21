//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGIdentity.h"

#import "NSBundle+SRGIdentity.h"

NSString *SRGIdentityMarketingVersion(void)
{
    return SWIFTPM_MODULE_BUNDLE.infoDictionary[@"CFBundleShortVersionString"];
}
