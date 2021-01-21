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

### URL scheme support (iOS only)

Your application must declare at least one [custom URL scheme](https://developer.apple.com/documentation/uikit/core_app/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app), which is then used by the framework to transfer control back from the web browser after logging in.

If your application already uses custom schemes for other purposes, implement the required URL handling method as usual:

* For application with scene support (iOS 13 and above): `- scene:openURLContexts:`.
* For applications without scene support: `-application:openURL:options:` 

If no custom URL scheme is used by your application, implementing a URL handling method is not required, as the framework will take care of injecting a default implementation at runtime so that URL handling works. You still need to define a URL scheme in your `Info.plist` file, though.

### Login

To allow for a user to login, call the `-loginWithEmailAddress:` instance method:

```objective-c
[SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
```

- On iOS this presents a browser, in which the user can supply her credentials or open an account.
- On tvOS a dedicated in-app view is presented, with which users can only log in (a message invite them to open an account on a computer or mobile device).
	- You can customize the logo displayed on this view by adding an `identity_service_logo` image file to your project (with recommended size of 150x150 px).
	- To autofill her credentials from a companion device, use `webcredentials` service by adding [the associated domains entitlement to your application and the associated domain file](https://developer.apple.com/documentation/safariservices/supporting_associated_domains) on your website.

A user remains logged in until she logs out.

#### Remark

On iOS, login occurs within a simple Safari in-app browser by default. Starting with iOS 11, you might prefer using an authentication session, which lets user credentials be shared between your app and Safari, providing automatic login for apps associated with the same identity provider. Before the user can enter her credentials, a system alert will be displayed to inform her about credential sharing.

To enable this feature, use the corresponding login method when creating the service:

```objective-c
SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithWebserviceURL:webserviceURL websiteURL:websiteURL loginMethod:SRGIdentityLoginMethodAuthenticationSession];
```

On iOS 10 devices and older, the default Safari in-app browser will be used instead.

### Token

Once a user has successfully logged in, a corresponding session token is available in the keychain. Use the `SRGIdentityService.currentIdentityService.sessionToken` property when you need to retrieve it.

### Account page (iOS only)

When a user is logged in, its account information can be displayed and edited within your application through a dedicated web page. To display this page, call `-showAccountView`:

```objective-c
[SRGIdentityService.currentIdentityService showAccountView];
```

tvOS users must currently manage their account from a computer or mobile device.

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
