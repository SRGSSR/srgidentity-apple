//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

/**
 *  Represents the authentication flow.
 */
@protocol SRGAuthenticationDelegate <NSObject>

/**
 *  Cancels the code flow session, invoking the request's callback with a cancelled error.
 *
 *  @discussion It has no effect if called more than once, or after a resumeauthenticationWithURL: message was received.
 *  Will cause an error with code `SRGAuthenticationCanceled`.
 */
- (void)cancelauthentication;

/**
 *  Clients should call this method with the result of the authentication if it becomes available.
 *
 *  @param URL The redirect URL invoked by the server.
 *
 *  @return YES if the passed URL matches the expected redirect URL and was consumed, NO otherwise.
 *
 *  @discussion Has no effect if called more than once, or after a `cancelauthentication` message was received.
 */
- (BOOL)resumeauthenticationWithURL:(NSURL *)URL;

/**
 *  Clients should call this method when the authentication flow failed with a non-token error.
 *
 *  @param error The error that is the reason for the failure of this authentication flow.
 *
 *  @discussion Has no effect if called more than once, or after a @c cancel message was received.
 */
- (void)failauthenticationWithError:(NSError *)error;

@end
