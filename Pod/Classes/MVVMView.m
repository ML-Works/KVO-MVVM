//
//  MVVMView.m
//  KVO-MVVM
//
//  Created by Anton Bukov on 16.03.16.
//
//

#import <objc/runtime.h>
#import "MVVMView.h"

static void *MVVMViewContext = &MVVMViewContext;

@interface MVVMView ()

@property (strong, nonatomic) NSMutableDictionary<NSString *, void (^)(id, id)> *mvvm_blocks;

@end

@implementation MVVMView

- (NSMutableDictionary<NSString *, void (^)(id, id)> *)mvvm_blocks {
    if (_mvvm_blocks == nil) {
        _mvvm_blocks = [NSMutableDictionary dictionary];
    }
    return _mvvm_blocks;
}

- (void)mvvm_observe:(NSString *)keyPath with:(void (^)(id self, id value))block {
    NSAssert(!self.mvvm_blocks[keyPath], @"You are not able to observe same keypath twice!");
    self.mvvm_blocks[keyPath] = [block copy];
    [self addObserver:self forKeyPath:keyPath options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:MVVMViewContext];
}

- (void)mvvm_unobserve:(NSString *)keyPath {
    if (self.mvvm_blocks[keyPath]) {
        [self.mvvm_blocks removeObjectForKey:keyPath];
        [self removeObserver:self forKeyPath:keyPath];
    }
}

- (void)mvvm_unobserveAll {
    for (NSString *keyPath in self.mvvm_blocks) {
        [self removeObserver:self forKeyPath:keyPath];
    }
    self.mvvm_blocks = nil;
}

- (void)mvvm_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    id newValue = change[NSKeyValueChangeNewKey];
    id oldValue = change[NSKeyValueChangeOldKey];
    if ([newValue isEqual:oldValue]) {
        return;
    }

    if (self.mvvm_blocks[keyPath]) {
        self.mvvm_blocks[keyPath](self, (newValue != [NSNull null]) ? newValue : nil);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    if (context != MVVMViewContext) {
        if ([[MVVMView superclass] instancesRespondToSelector:_cmd]) {
            [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
        return;
    }

    [self mvvm_observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)dealloc {
    [self mvvm_unobserveAll];
}

@end
