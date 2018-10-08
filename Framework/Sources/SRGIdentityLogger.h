//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGLogger/SRGLogger.h>

/**
 *  Helper macros for logging.
 */
#define SRGIdentityLogVerbose(category, format, ...) SRGLogVerbose(@"ch.srgssr.analytics", category, format, ##__VA_ARGS__)
#define SRGIdentityLogDebug(category, format, ...)   SRGLogDebug(@"ch.srgssr.analytics", category, format, ##__VA_ARGS__)
#define SRGIdentityLogInfo(category, format, ...)    SRGLogInfo(@"ch.srgssr.analytics", category, format, ##__VA_ARGS__)
#define SRGIdentityLogWarning(category, format, ...) SRGLogWarning(@"ch.srgssr.analytics", category, format, ##__VA_ARGS__)
#define SRGIdentityLogError(category, format, ...)   SRGLogError(@"ch.srgssr.analytics", category, format, ##__VA_ARGS__)
