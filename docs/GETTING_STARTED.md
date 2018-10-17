Getting started
===============

This getting started guide discusses all concepts required to use the SRG Identity library.

## Service instantiation

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

## Login

To allow for a user to login, call the `-loginWithEmailAddress:` instance method:

```objective-c
[SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
```

This presents a sandboxed Safari browser, in which the user can supply her credentials or open an account. A user remains logged in until she logs out.

## Token

Once a user has successfully logged in, a corresponding session token is available in the keychain. Use the `SRGIdentityService.currentIdentityService.sessionToken` property when you need it.

### Logout

To logout the current user, simply call `-logout`;

```objective-c
[SRGIdentityService.currentIdentityService logout];
```

## iOS 9 and 10 support

iOS 9 and 10 support requires your application to declare at least one [custom URL scheme](https://developer.apple.com/documentation/uikit/core_app/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app), which is then used by the framework to transfer control back from Safari to your application after successful login.

If your application uses custom schemes for other purposes, implement the `-application:openURL:options:` application delegate method as usual. If no explicit URL handling is required, implementing this method is not required, as the framework will take care of injecting an implementation at runtime so that URL handling works.