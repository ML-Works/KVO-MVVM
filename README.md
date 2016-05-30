# KVO-MVVM

[![CI Status](http://img.shields.io/travis/ML-Works/KVO-MVVM.svg?style=flat)](https://travis-ci.org/ML-Works/KVO-MVVM)
[![Version](https://img.shields.io/cocoapods/v/KVO-MVVM.svg?style=flat)](http://cocoapods.org/pods/KVO-MVVM)
[![License](https://img.shields.io/cocoapods/l/KVO-MVVM.svg?style=flat)](http://cocoapods.org/pods/KVO-MVVM)
[![Platform](https://img.shields.io/cocoapods/p/KVO-MVVM.svg?style=flat)](http://cocoapods.org/pods/KVO-MVVM)

## Usage

1. First `#import <KVO-MVVM/KVO-MVVM.h>`

2. Then subclass from any of classes listed:
   * MVVMObject
   * MVVMViewController
   * MVVMView
   * MVVMTableView
   * MVVMTableViewCell
   * MVVMCollectionView
   * MVVMCollectionViewCell
   * MVVMCollectionReusableView

3. Finally use `mvvm_observe:with:` like this:
```objective-c
   - (instancetype)initWithFrame:(CGRect)frame {
       if (self = [super initWithFrame:frame]) {

           [self mvvm_observe:@keypath(self.viewModel.title) with:^(typeof(self) self, NSString *title) {
               self.titleLabel.text = self.viewModel.title;
           }];
           
           [self mvvm_observe:@keypath(self.viewModel.value) with:^(typeof(self) self, NSNumber *value) {
               self.valueLabel.text = [NSString stringWithFormat:@"Value = %f", self.viewModel.value);
           }];

       }
       return self;
   }
```

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

KVO-MVVM is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'KVO-MVVM'
```

## Author

Anton Bukov, k06a@mlworks.com
Andrew Podkovyrin, podkovyrin@mlworks.com

## License

KVO-MVVM is available under the MIT license. See the LICENSE file for more info.
