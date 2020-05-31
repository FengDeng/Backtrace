# Backtrace

[![Version](https://img.shields.io/cocoapods/v/BacktraceSwift.svg?style=flat)](https://cocoapods.org/pods/BacktraceSwift)
[![License](https://img.shields.io/cocoapods/l/BacktraceSwift.svg?style=flat)](https://cocoapods.org/pods/BacktraceSwift)
[![Platform](https://img.shields.io/cocoapods/p/BacktraceSwift.svg?style=flat)](https://cocoapods.org/pods/BacktraceSwift)



[如何捕获任意线程调用栈信息-Swift](https://juejin.im/post/5ed3dfd06fb9a047f0126ceb)

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

iOS  8.0+
Swift 5.0+

## Installation

Backtrace is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'BacktraceSwift'
```

## Author

邓锋, raisechestnut@gmail.com

## License

Backtrace is available under the MIT license. See the LICENSE file for more info.
