//
//  NSObject+MVVMKVOPrivate.m
//  KVO-MVVM
//
//  Created by Andrew Podkovyrin on 16/03/16.
//
//

#import <objc/message.h>
#import <objc/runtime.h>

#import "NSObject+MVVMKVOPrivate.h"

static void *MVVMKVOContext = &MVVMKVOContext;

#pragma mark -

typedef void (^ObserveBlock)(id self, id value);
typedef void (^ObserveCollectionBlock)(id self, id value, NSKeyValueChange change, NSIndexSet *indexes);
typedef NSMutableArray<ObserveBlock> ObserveBlocksArray;
typedef NSMutableArray<ObserveCollectionBlock> ObserveCollectionBlocksArray;
typedef NSMutableDictionary<NSString *, ObserveBlocksArray *> ObserveBlocksDictionary;
typedef NSMutableDictionary<NSString *, ObserveCollectionBlocksArray *> ObserveCollectionBlocksDictionary;

@interface NSObject (MVVMKVOPrivate_Properties)

@property (strong, nonatomic) ObserveBlocksDictionary *mvvm_blocks;
@property (strong, nonatomic) ObserveCollectionBlocksDictionary *mvvm_collection_blocks;

@end

@implementation NSObject (MVVMKVOPrivate_Properties)

- (ObserveBlocksDictionary *)mvvm_blocks {
    NSMutableDictionary *blocks = objc_getAssociatedObject(self, @selector(mvvm_blocks));
    if (blocks == nil) {
        blocks = [NSMutableDictionary dictionary];
        self.mvvm_blocks = blocks;
    }
    return blocks;
}

- (void)setMvvm_blocks:(ObserveBlocksDictionary *)mvvm_blocks {
    objc_setAssociatedObject(self, @selector(mvvm_blocks), mvvm_blocks, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ObserveCollectionBlocksDictionary *)mvvm_collection_blocks {
    NSMutableDictionary *blocks = objc_getAssociatedObject(self, @selector(mvvm_collection_blocks));
    if (blocks == nil) {
        blocks = [NSMutableDictionary dictionary];
        self.mvvm_collection_blocks = blocks;
    }
    return blocks;
}

- (void)setMvvm_collection_blocks:(ObserveCollectionBlocksDictionary *)mvvm_collection_blocks {
    objc_setAssociatedObject(self, @selector(mvvm_collection_blocks), mvvm_collection_blocks, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation NSObject (MVVMKVOPrivate)

- (void)mvvm_observe:(NSString *)keyPath with:(ObserveBlock)block {
    return [self mvvm_observe:keyPath options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) with:block];
}

- (void)mvvm_observe:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(ObserveCollectionBlock)block {
    if (!self.mvvm_blocks[keyPath]) {
        self.mvvm_blocks[keyPath] = [NSMutableArray array];
    }
    [self.mvvm_blocks[keyPath] addObject:[block copy]];

    if (self.mvvm_blocks[keyPath].count == 1) {
        [self addObserver:self forKeyPath:keyPath options:options context:MVVMKVOContext];
    }
    else if (options | NSKeyValueObservingOptionInitial) {
        self.mvvm_blocks[keyPath].lastObject(self, [self valueForKeyPath:keyPath]);
    }
}

- (void)mvvm_observeCollection:(NSString *)keyPath with:(ObserveCollectionBlock)block {
    return [self mvvm_observeCollection:keyPath options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) with:block];
}

- (void)mvvm_observeCollection:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(ObserveCollectionBlock)block {
    if (!self.mvvm_collection_blocks[keyPath]) {
        self.mvvm_collection_blocks[keyPath] = [NSMutableArray array];
    }
    [self.mvvm_collection_blocks[keyPath] addObject:[block copy]];

    if (self.mvvm_collection_blocks[keyPath].count == 1) {
        [self addObserver:self forKeyPath:keyPath options:options context:MVVMKVOContext];
    }
    else if (options | NSKeyValueObservingOptionInitial) {
        self.mvvm_collection_blocks[keyPath].lastObject(self, [self valueForKeyPath:keyPath], 0, [NSIndexSet indexSet]);
    }
}

- (void)mvvm_unobserve:(NSString *)keyPath {
    if (self.mvvm_blocks[keyPath]) {
        [self.mvvm_blocks removeObjectForKey:keyPath];
        [self removeObserver:self forKeyPath:keyPath];
    }
    if (self.mvvm_collection_blocks[keyPath]) {
        [self.mvvm_collection_blocks removeObjectForKey:keyPath];
        [self removeObserver:self forKeyPath:keyPath];
    }
}

- (void)mvvm_unobserveAll {
    for (NSString *keyPath in self.mvvm_blocks) {
        [self removeObserver:self forKeyPath:keyPath];
    }
    for (NSString *keyPath in self.mvvm_collection_blocks) {
        [self removeObserver:self forKeyPath:keyPath];
    }
    self.mvvm_blocks = nil;
    self.mvvm_collection_blocks = nil;
}

- (void)mvvm_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context superClass:(Class)superClass {
    if (context != MVVMKVOContext) {
        SEL sel = @selector(observeValueForKeyPath:ofObject:change:context:);
        if ([superClass instancesRespondToSelector:sel]) {
            struct objc_super mySuper = {
                .receiver = self,
                .super_class = superClass,
            };

            id (*objc_superClassKVOMethod)(struct objc_super *, SEL, id, id, id, void *) = (void *)&objc_msgSendSuper;
            objc_superClassKVOMethod(&mySuper, sel, keyPath, object, change, context);
            // [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
        return;
    }

    id newValue = nil;
    NSIndexSet *indexes = nil;
    NSKeyValueChange changeType = [change[NSKeyValueChangeKindKey] unsignedIntegerValue];
    if (changeType == NSKeyValueChangeSetting) {
        newValue = change[NSKeyValueChangeNewKey];
        id oldValue = change[NSKeyValueChangeOldKey];
        if ([newValue isEqual:oldValue]) {
            return;
        }
    }
    else {
        newValue = [object valueForKeyPath:keyPath];
        indexes = change[NSKeyValueChangeIndexesKey];
        if (indexes.count == 0) {
            return;
        }
    }

    for (ObserveBlock block in self.mvvm_blocks[keyPath]) {
        block(self, (newValue != [NSNull null]) ? newValue : nil);
    }
    for (ObserveCollectionBlock block in self.mvvm_collection_blocks[keyPath]) {
        block(self, (newValue != [NSNull null]) ? newValue : nil, changeType, indexes);
    }
}

@end
