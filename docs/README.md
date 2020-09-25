[![SRG Identity logo](README-images/logo.png)](https://github.com/SRGSSR/srgidentity-apple)

[![GitHub releases](https://img.shields.io/github/v/release/SRGSSR/srgidentity-apple)](https://github.com/SRGSSR/srgidentity-apple/releases) [![platform](https://img.shields.io/badge/platfom-ios%20%7C%20tvos-blue)](https://github.com/SRGSSR/srgidentity-apple) [![SPM compatible](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager) [![Build Status](https://travis-ci.org/SRGSSR/srgidentity-apple.svg?branch=master)](https://travis-ci.org/SRGSSR/srgidentity-apple/branches) [![GitHub license](https://img.shields.io/github/license/SRGSSR/srgidentity-apple)](https://github.com/SRGSSR/srgidentity-apple/blob/master/LICENSE)

## About

The SRG Identity framework is a simple way to authenticate users within SRG SSR applications.

## Compatibility

The library is suitable for applications running on iOS 9, tvOS 12 and above. The project is meant to be compiled with the latest Xcode version.

## Contributing

If you want to contribute to the project, have a look at our [contributing guide](CONTRIBUTING.md).

## Integration

The library must be integrated using [Swift Package Manager](https://swift.org/package-manager) directly [within Xcode](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app). You can also declare the library as a dependency of another one directly in the associated `Package.swift` manifest.

## Usage

When you want to use classes or functions provided by the library in your code, you must import it from your source files first. In Objective-C:

```objective-c
@import SRGIdentity;
```

or in Swift:

```swift
import SRGIdentity
```

### Working with the library

To learn about how the library can be used, have a look at the [getting started guide](GETTING_STARTED.md).

### Logging

The library internally uses the [SRG Logger](https://github.com/SRGSSR/srglogger-apple) library for logging, within the `ch.srgssr.identity` subsystem. This logger either automatically integrates with your own logger, or can be easily integrated with it. Refer to the SRG Logger documentation for more information.

## License

See the [LICENSE](../LICENSE) file for more information.
