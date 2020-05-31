# Backtrace

[![Version](https://img.shields.io/cocoapods/v/Backtrace.svg?style=flat)](https://cocoapods.org/pods/Backtrace)
[![License](https://img.shields.io/cocoapods/l/Backtrace.svg?style=flat)](https://cocoapods.org/pods/Backtrace)
[![Platform](https://img.shields.io/cocoapods/p/Backtrace.svg?style=flat)](https://cocoapods.org/pods/Backtrace)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Usage

```swift 

import Backtrace

Backtrace.backtrace(thread: Thread)->String
Backtrace.backtraceMainThread()->String
Backtrace.backtraceCurrentThread()->String
Backtrace.backtraceAllThread()->[String]
```

## Requirements

## Installation

Backtrace is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Backtrace'
```

## Author

邓锋, raisechestnut@gmail.com

## License

Backtrace is available under the MIT license. See the LICENSE file for more info.
