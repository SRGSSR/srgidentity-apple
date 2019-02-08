Getting started
===============

This getting started guide discusses all concepts required to use the SRG Identity library.

### Service instantiation

At its core, the SRG Identity library reduces to a single identity service class, `SRGIdentityService`, which you instantiate for a given (identity provider URL and an identity website where you can login, for example:

```objective-c
SRGIdentityService *identityService = [[SRGIdentityService alloc] initWithWebserviceURL:webserviceURL websiteURL:websiteURL];
```

Both the webservice URLs and website URL must provide services expected by the library to work (convention over configuration).

You can have several identity services in an application, though most applications should require only one. To make it easier to access the main identity service of an application, the `SRGIdentityService ` class provides a class property to set and retrieved it as shared instance:

```objective-c
SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithWebserviceURL:webserviceURL websiteURL:websiteURL];
```

For simplicity, this getting started guide assumes that a shared service has been set. If you cannot use the shared instance, store the services you instantiated somewhere and provide access to them in some way.

### Login

To allow for a user to login, call the `-loginWithEmailAddress:` instance method:

```objective-c
[SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
```

This presents a sandboxed Safari browser, in which the user can supply her credentials or open an account. A user remains logged in until she logs out.

#### Remark

Login occurs within a simple Safari in-app browser by default. Starting with iOS 11, you might prefer using an authentication session, which lets user credentials be shared between your app and Safari, providing automatic login for apps associated with the same identity provider. Before the user can enter her credentials, a system alert will be displayed to inform her about credential sharing.

To enable this feature, use the corresponding login method when creating the service:

```objective-c
SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithWebserviceURL:webserviceURL websiteURL:websiteURL loginMethod:SRGIdentityLoginMethodAuthenticationSession];
```

On iOS 10 devices and older, the default Safari in-app browser will be used instead.

### Token

Once a user has successfully logged in, a corresponding session token is available in the keychain. Use the `SRGIdentityService.currentIdentityService.sessionToken` property when you need to retrieve it.

### Account page

When a user is logged in, its account information can be displayed and edited within your application through a dedicated web page. Display this page requires the use of a custom web browser supporting `NSURLRequest` as input. `SFSafariViewController` is therefore not natively supported at the moment, as it requires a simple `NSURL`.

When a user is logged in, your application can call `-[SRGIdentityService showAccountViewWithPresentation:dismissal:]` to initiate the account display process. This generates the required URL request for displaying the account page and calls a presentation block, within which your application can instantiate the web browser and install it within its view controller hierarchy.

As the user interacts with the account page in the displayed web browser, URLs to which the browser navigates must be handed over to a URL handler block (provided to the presentation block as a parameter). This block will process each URL supplied to it, process identified actions (e.g. account deletion) and return a recommended action your browser implementation should follow (either continue or cancel navigation).

When calling the account display method above, you must also provide a dismissal block, which must implement how the web browser must be removed from view. You can manually trigger this block by calling `-[SRGIdentityService hideAccountView]`, but it will usually be triggered by identified account web page actions, for example when the account is deleted.

For concrete implementation details, please have a look at the demo project.

### Logout

To logout the current user, simply call `-logout`;

```objective-c
[SRGIdentityService.currentIdentityService logout];
```

### Integration with third-party services

SRG Identity only takes care of authenticating a user. Once a token has been retrieved, your application is namely responsible for calling other webservices on behalf of this user. Usually, this is achieved by providing the session token in webservice requests, how this is actually made depending on the service.

Server-side, third-party services themselves are integrated with the identity provider server to support authenticated requests. Since your application merely connects to third-party services to perform its work, it might receive an unauthorization error from them at some point. Since third-party services are not identity providers, though, your application should not rely on such errors to force a user to logout or to clear local data. The third-party service might be wrong.

Instead, if you receive an unauthorization error from a third-party service, call `-reportUnauthorization` on the identity service from which the token was used. This forces a check with the identity provider to verify whether the user is truly unauthorized or not:

* If still authorized, nothing happens beside an account update. 
* If confirmed to be unauthorized, the user is automatically logged out. In such cases, the `SRGIdentityServiceUserDidLogoutNotification` notification is sent with `SRGIdentityServiceUnauthorizedKey` set to `@YES` in its `userInfo` dictionary. You can for example use this information to display a corresponding information message to the user.

### iOS 9 and 10 support

iOS 9 and 10 support requires your application to declare at least one [custom URL scheme](https://developer.apple.com/documentation/uikit/core_app/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app), which is then used by the framework to transfer control back from Safari to your application after successful login.

If your application uses custom schemes for other purposes, implement the `-application:openURL:options:` application delegate method as usual. If no explicit URL handling is required, implementing this method is not required, as the framework will take care of injecting an implementation at runtime so that URL handling works.