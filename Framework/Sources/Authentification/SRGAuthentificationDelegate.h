//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

/**
 *  Represents the authentification flow.
 */
@protocol SRGAuthentificationDelegate <NSObject>

/**
 *  Cancels the code flow session, invoking the request's callback with a cancelled error.
 *
 *  @discussion It has no effect if called more than once, or after a resumeAuthentificationWithURL: message was received.
 *  Will cause an error with code `SRGAuthentificationCanceled`.
 */
- (void)cancelAuthentification;

/**
 *  Clients should call this method with the result of the authentification if it becomes available.
 *
 *  @param URL The redirect URL invoked by the server.
 *
 *  @return YES if the passed URL matches the expected redirect URL and was consumed, NO otherwise.
 *
 *  @discussion Has no effect if called more than once, or after a `cancelAuthentification` message was received.
 */
- (BOOL)resumeAuthentificationWithURL:(NSURL *)URL;

/**
 *  Clients should call this method when the authentification flow failed with a non-token error.
 *
 *  @param error The error that is the reason for the failure of this authentification flow.
 *
 *  @discussion Has no effect if called more than once, or after a @c cancel message was received.
 */
- (void)failAuthentificationWithError:(NSError *)error;

@end
