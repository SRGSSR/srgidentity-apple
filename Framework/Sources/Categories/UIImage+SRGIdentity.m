//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UIImage+SRGIdentity.h"

#import "NSBundle+SRGIdentity.h"

@implementation UIImage (SRGIdentityImages)

+ (UIImage *)srg_identityImageNamed:(NSString *)imageName
{
    return [UIImage imageNamed:imageName inBundle:NSBundle.srg_identityBundle compatibleWithTraitCollection:nil];
}

@end
