//
//  KVO-MVVM.m
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

#import <objc/message.h>

#import <JRSwizzle/JRSwizzle.h>

#import "KVO-MVVM.h"

//

static void *MVVMKVOContext = &MVVMKVOContext;

//

#pragma mark - Typedefs

typedef void (^ObserveBlock)(id self, id value);
typedef void (^ObserveCollectionBlock)(id self, id value, NSKeyValueChange change, NSIndexSet *indexes);
typedef NSMutableArray<ObserveBlock> ObserveBlocksArray;
typedef NSMutableArray<ObserveCollectionBlock> ObserveCollectionBlocksArray;
typedef NSMutableDictionary<NSString *, ObserveBlocksArray *> ObserveBlocksDictionary;
typedef NSMutableDictionary<NSString *, ObserveCollectionBlocksArray *> ObserveCollectionBlocksDictionary;

//

#pragma mark - Private NSObject methods

@class KVOMVVMHolder;

@interface NSObject (MVVMKVO_Private)

- (void)mvvm_observeValueForKeyPath:(NSString *)keyPath
                           ofObject:(id)object
                             change:(NSDictionary<NSString *, id> *)change
                            context:(void *)context;

- (void)mvvm_unobserveAllWithUnobserver:(KVOMVVMHolder *)unobserver;

@end

//

#pragma mark - Unobserver

@interface KVOMVVMHolder : NSObject

@property (strong, nonatomic) ObserveBlocksDictionary *blocks;
@property (strong, nonatomic) ObserveCollectionBlocksDictionary *collectionBlocks;

@end

@implementation KVOMVVMHolder

- (ObserveBlocksDictionary *)blocks {
    if (_blocks == nil) {
        _blocks = [ObserveBlocksDictionary dictionary];
    }
    return _blocks;
}

- (ObserveCollectionBlocksDictionary *)collectionBlocks {
    if (_collectionBlocks == nil) {
        _collectionBlocks = [ObserveCollectionBlocksDictionary dictionary];
    }
    return _collectionBlocks;
}

@end

#pragma mark -

@interface NSObject (MVVMKVOPrivate)

@property (readonly, nonatomic) KVOMVVMHolder *mvvm_holder;

@end

@implementation NSObject (MVVMKVOPrivate)

@dynamic mvvm_holder;

- (id)mvvm_holder {
    KVOMVVMHolder *holder = objc_getAssociatedObject(self, _cmd);
    if (holder == nil) {
        holder = [[KVOMVVMHolder alloc] init];
        objc_setAssociatedObject(self, _cmd, holder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return holder;
}

+ (void)load {
    NSError *error;
    if (![self jr_swizzleMethod:@selector(observeValueForKeyPath:ofObject:change:context:) withMethod:@selector(mvvm_observeValueForKeyPath:ofObject:change:context:) error:&error]) {
        NSLog(@"Swizzling [%@ %@] error: %@", self, NSStringFromSelector(@selector(observeValueForKeyPath:ofObject:change:context:)), error);
    }
}

- (void)mvvm_observe:(NSString *)keyPath with:(ObserveBlock)block {
    return [self mvvm_observe:keyPath options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) with:block];
}

- (void)mvvm_observe:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(ObserveCollectionBlock)block {
    if (!self.mvvm_holder.blocks[keyPath]) {
        self.mvvm_holder.blocks[keyPath] = [NSMutableArray array];
    }
    [self.mvvm_holder.blocks[keyPath] addObject:[block copy]];

    if (self.mvvm_holder.blocks[keyPath].count == 1) {
        [self addObserver:self forKeyPath:keyPath options:options context:MVVMKVOContext];
    }
    else if (options | NSKeyValueObservingOptionInitial) {
        self.mvvm_holder.blocks[keyPath].lastObject(self, [self valueForKeyPath:keyPath]);
    }
}

- (void)mvvm_observeCollection:(NSString *)keyPath with:(ObserveCollectionBlock)block {
    return [self mvvm_observeCollection:keyPath options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) with:block];
}

- (void)mvvm_observeCollection:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(ObserveCollectionBlock)block {
    if (!self.mvvm_holder.collectionBlocks[keyPath]) {
        self.mvvm_holder.collectionBlocks[keyPath] = [NSMutableArray array];
    }
    [self.mvvm_holder.collectionBlocks[keyPath] addObject:[block copy]];

    if (self.mvvm_holder.collectionBlocks[keyPath].count == 1) {
        [self addObserver:self forKeyPath:keyPath options:options context:MVVMKVOContext];
    }
    else if (options | NSKeyValueObservingOptionInitial) {
        self.mvvm_holder.collectionBlocks[keyPath].lastObject(self, [self valueForKeyPath:keyPath], 0, [NSIndexSet indexSet]);
    }
}

- (void)mvvm_unobserve:(NSString *)keyPath {
    if (self.mvvm_holder.blocks[keyPath]) {
        [self.mvvm_holder.blocks removeObjectForKey:keyPath];
        [self removeObserver:self forKeyPath:keyPath context:MVVMKVOContext];
    }
    if (self.mvvm_holder.collectionBlocks[keyPath]) {
        [self.mvvm_holder.collectionBlocks removeObjectForKey:keyPath];
        [self removeObserver:self forKeyPath:keyPath context:MVVMKVOContext];
    }
}

- (void)mvvm_unobserveAll {
    [self mvvm_unobserveAllWithUnobserver:self.mvvm_holder];
}

- (void)mvvm_unobserveAllWithUnobserver:(KVOMVVMHolder *)unobserver {
    for (NSString *keyPath in unobserver.blocks) {
        [self removeObserver:self forKeyPath:keyPath context:MVVMKVOContext];
    }
    for (NSString *keyPath in unobserver.collectionBlocks) {
        [self removeObserver:self forKeyPath:keyPath context:MVVMKVOContext];
    }
    unobserver.blocks = nil;
    unobserver.collectionBlocks = nil;
}

- (void)mvvm_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    if (context != MVVMKVOContext) {
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

    for (ObserveBlock block in self.mvvm_holder.blocks[keyPath]) {
        block(self, (newValue != [NSNull null]) ? newValue : nil);
    }
    for (ObserveCollectionBlock block in self.mvvm_holder.collectionBlocks[keyPath]) {
        block(self, (newValue != [NSNull null]) ? newValue : nil, changeType, indexes);
    }
}

@end
