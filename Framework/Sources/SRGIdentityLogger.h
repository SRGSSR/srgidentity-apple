//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGLogger/SRGLogger.h>

/**
 *  Helper macros for logging.
 */
#define SRGIdentityLogVerbose(category, format, ...) SRGLogVerbose(@"ch.srgssr.identity", category, format, ##__VA_ARGS__)
#define SRGIdentityLogDebug(category, format, ...)   SRGLogDebug(@"ch.srgssr.identity", category, format, ##__VA_ARGS__)
#define SRGIdentityLogInfo(category, format, ...)    SRGLogInfo(@"ch.srgssr.identity", category, format, ##__VA_ARGS__)
#define SRGIdentityLogWarning(category, format, ...) SRGLogWarning(@"ch.srgssr.identity", category, format, ##__VA_ARGS__)
#define SRGIdentityLogError(category, format, ...)   SRGLogError(@"ch.srgssr.identity", category, format, ##__VA_ARGS__)
