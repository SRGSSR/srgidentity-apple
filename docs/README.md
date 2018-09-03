<p align="center"><img src="README-images/logo.png"/></p>

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

## About

The RTS Identity framework contains the Peach authentification logic.

## Compatibility

The library is suitable for applications running on iOS 9 and above. The project is meant to be opened with the latest Xcode version (currently Xcode 9).

## Installation

The library can be added to a project using [Carthage](https://github.com/Carthage/Carthage) by adding the following dependency to your `Cartfile`:
    
```
git "https://bitbucket.org/rtsmb/rtsidentity-ios.git"
```

Until Carthage 0.30, only dynamic frameworks could be integrated. Starting with Carthage 0.30, though, frameworks can be integrated statically as well, which avoids slow application startups usually associated with the use of too many dynamic frameworks.

For more information about Carthage and its use, refer to the [official documentation](https://github.com/Carthage/Carthage).

### Dependencies

The library requires the following frameworks to be added to any target requiring it:

* `libextobjc`: An utility framework.
* `MAKVONotificationCenter`: A safe KVO framework.
* `Mantle`: The framework used to parse the data.
* `RTSIdentity`: The identity library framework.
* `UICKeyChainStore`: The framework used to store credentials in keychains.
* `WebKit`: Apple web framework to display authentification.

### Dynamic framework integration

1. Run `carthage update` to update the dependencies (which is equivalent to `carthage update --configuration Release`). 
2. Add the frameworks listed above and generated in the `Carthage/Build/iOS` folder to your target _Embedded binaries_.

If your target is building an application, a few more steps are required:

1. Add a _Run script_ build phase to your target, with `/usr/local/bin/carthage copy-frameworks` as command.
2. Add each of the required frameworks above as input file `$(SRCROOT)/Carthage/Build/iOS/FrameworkName.framework`.

### Static framework integration

1. Run `carthage update --configuration Release-static` to update the dependencies. 
2. Add the frameworks listed above and generated in the `Carthage/Build/iOS/Static` folder to the _Linked frameworks and libraries_ list of your target.
3. Also add any resource bundle `.bundle` found within the `.framework` folders to your target directly.
4. Add the `-all_load` flag to your target _Other linker flags_.

## Usage

When you want to use classes or functions provided by the library in your code, you must import it from your source files first.

### Usage from Objective-C source files

Import the global header file using:

```objective-c
#import <RTSIdentity/RTSIdentity.h>
```

or directly import the module itself:

```objective-c
@import RTSIdentity;
```

### Usage from Swift source files

Import the module where needed:

```swift
import RTSIdentity
```

### Identity instantation and access

At its core, the RTS Identity library reduces to a single identity service class, `RTSIdentityService`, which you instantiate for a service URL, for example:

```objective-c
RTSIdentityService *identityService = [[RTSIdentityService alloc] initWithServiceURL:[NSURL URLWithString:@"https://id.rts.ch" accessGroup:@"VMGRRW6SG7.ch.rts.identity"]];
```

NB: To use keychain `accessGroup`, add it also `keychain-access-groups` in the application entitlements.

A set of identity values are provided. You can have several identity services in an application, though most applications should require only one. To make it easier to access the main identity service of an application, the `RTSIdentityService ` class provides class methods to set it as shared instance:

```objective-c
RTSIdentityService *identityService = ...;
[RTSIdentityService setCurrentIdentityService:identityService];
```

and to retrieve it from anywhere, for example when creating a request:

```objective-c
RTSIdentityService *identityService = [RTSIdentityService currentIdentityService];
```

### Login

To authentifiate, use `RTSIdentityLoginView`.

### Manage account

To display and update the user profile, use `RTSIdentityAccountView`.

### Logout

To logout, use `-logout`.

## License

See the [LICENSE](../LICENSE) file for more information.
