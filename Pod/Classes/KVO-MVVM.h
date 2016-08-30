//
//  KVO-MVVM.h
//  KVO-MVVM
//
//  Created by Anton Bukov on 16.03.16.
//
//

#import <Foundation/Foundation.h>

#import "NSObject+MLWKVOMVVMUnobserver.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (MLWKVOMVVM)

- (void)mvvm_observe:(NSString *)keyPath with:(void (^)(id self, id value))block;
- (void)mvvm_observe:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(void (^)(id self, id value))block;
- (void)mvvm_observeCollection:(NSString *)keyPath with:(void (^)(id self, id value, NSKeyValueChange change, NSIndexSet *indexes))block;
- (void)mvvm_observeCollection:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(void (^)(id self, id value, NSKeyValueChange change, NSIndexSet *indexes))block;

- (void)mvvm_unobserve:(NSString *)keyPath;
- (void)mvvm_unobserveAll;

@end

NS_ASSUME_NONNULL_END
