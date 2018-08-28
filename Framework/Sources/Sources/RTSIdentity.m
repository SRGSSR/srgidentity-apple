//
//  Copyright (c) RTS. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RTSIdentity.h"

#import "NSBundle+RTSIdentity.h"

NSString *RTSIdentityMarketingVersion(void)
{
    return [NSBundle rts_identityBundle].infoDictionary[@"CFBundleShortVersionString"];
}
