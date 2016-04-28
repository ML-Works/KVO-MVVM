//
//  MVVMProtocol.h
//  KVO-MVVM
//
//  Created by Andrew Podkovyrin on 16/03/16.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MVVMKVO <NSObject>

- (void)mvvm_observe:(NSString *)keyPath with:(void (^)(id self, id value))block;
- (void)mvvm_observe:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(void (^)(id self, id value))block;
- (void)mvvm_unobserve:(NSString *)keyPath;
- (void)mvvm_unobserveAll;
- (void)mvvm_observeValueForKeyPath:(NSString *)keyPath
                           ofObject:(id)object
                             change:(NSDictionary<NSString *, id> *)change
                            context:(void *)context
                         superClass:(Class)superClass;

@end

NS_ASSUME_NONNULL_END
