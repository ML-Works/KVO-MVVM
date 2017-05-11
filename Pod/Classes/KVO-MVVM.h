//
//  KVO-MVVM.h
//  KVO-MVVM
//
//  Copyright (c) 2016 Machine Learning Works
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (KVOMVVM)

- (id)mvvm_observe:(NSString *)keyPath with:(void (^)(id self, id _Nullable value))block;
- (id)mvvm_observe:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(void (^)(id self, id _Nullable value))block;
- (id)mvvm_observeCollection:(NSString *)keyPath with:(void (^)(id self, id _Nullable value, NSKeyValueChange change, NSIndexSet *indexes))block;
- (id)mvvm_observeCollection:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(void (^)(id self, id _Nullable value, NSKeyValueChange change, NSIndexSet *indexes))block;

- (void)mvvm_unobserve:(NSString *)keyPath;
- (void)mvvm_unobserveLast:(NSString *)keyPath;
- (void)mvvm_unobserveBlock:(id)block;
- (void)mvvm_unobserveAll;

@end

NS_ASSUME_NONNULL_END
