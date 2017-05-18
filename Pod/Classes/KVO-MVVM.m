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
#import <RuntimeRoutines/RuntimeRoutines.h>

#import "KVO-MVVM.h"

//

static void *MVVMKVOContext = &MVVMKVOContext;

#ifdef DEBUG
static void CheckClassKeyPathForPropertiesNotGetters(Class klass, NSString *keyPath) {
    static NSMutableDictionary<Class, NSMutableSet<NSString *> *> *checked;
    if ([checked[klass] containsObject:keyPath]) {
        return;
    }
    
    Class currentClass = klass;
    for (NSString *key in [keyPath componentsSeparatedByString:@"."]) {
        for (NSString *affectingKeyPath in [currentClass keyPathsForValuesAffectingValueForKey:key]) {
            CheckClassKeyPathForPropertiesNotGetters(currentClass, affectingKeyPath);
        }
        
        objc_property_t property = class_getProperty(currentClass, key.UTF8String);
        if (!property) {
            RRClassEnumerateProperties(currentClass, ^(objc_property_t  _Nonnull property) {
                NSString *propertyName = @(property_getName(property));
                SEL getter = RRPropertyGetGetter(property);
                NSString *getterStr = NSStringFromSelector(getter);
                if (![getterStr isEqualToString:propertyName] && [key isEqualToString:getterStr] ) {
                    NSCAssert(NO, @"Class %@ can't not observe keypath \"%@\" use property name \"%@\" instead of getter name \"%@\"", klass, keyPath, propertyName, getterStr);
                }
            });
        }
        
        char *propertyTypePtr = property_copyAttributeValue(property, "T");
        NSString *type = [[NSString alloc] initWithBytesNoCopy:propertyTypePtr length:(propertyTypePtr ? strlen(propertyTypePtr) : 0) encoding:NSUTF8StringEncoding freeWhenDone:YES];
        
        if ([type rangeOfString:@"@\""].location == 0) {
            type = [type substringWithRange:NSMakeRange(2, type.length - 3)];
        }
        
        NSUInteger location = [type rangeOfString:@"<"].location;
        if (location != 0 && location != NSNotFound) {
            currentClass = NSClassFromString([type substringToIndex:location]);
        }
        else {
            currentClass = NSClassFromString(type);
        }
        
        if (currentClass == nil) {
            break;
        }
    }
    
    if (checked == nil) {
        checked = [NSMutableDictionary dictionary];
    }
    if (checked[klass] == nil) {
        checked[(id)klass] = [NSMutableSet setWithObject:keyPath];
    }
    else {
        [checked[klass] addObject:keyPath];
    }
}
#endif

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

- (id)mvvm_observe:(NSString *)keyPath with:(ObserveBlock)block {
    return [self mvvm_observe:keyPath options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) with:block];
}

- (id)mvvm_observe:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(ObserveBlock)block {
#ifdef DEBUG
    CheckClassKeyPathForPropertiesNotGetters([self class], keyPath);
#endif
    
    if (!self.mvvm_holder.blocks[keyPath]) {
        self.mvvm_holder.blocks[keyPath] = [NSMutableArray array];
    }
    [self.mvvm_holder.blocks[keyPath] addObject:[block copy]];

    if (self.mvvm_holder.blocks[keyPath].count == 1) {
        BOOL needInitialCall = (options & NSKeyValueObservingOptionInitial);
        if (needInitialCall) {
            options ^= NSKeyValueObservingOptionInitial;
        }
        [self addObserver:self forKeyPath:keyPath options:options context:MVVMKVOContext];
        if (needInitialCall) {
            block(self, [self valueForKeyPath:keyPath]);
        }
    }
    else if (options | NSKeyValueObservingOptionInitial) {
        block(self, [self valueForKeyPath:keyPath]);
    }
    
    return block;
}

- (id)mvvm_observeCollection:(NSString *)keyPath with:(ObserveCollectionBlock)block {
    return [self mvvm_observeCollection:keyPath options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) with:block];
}

- (id)mvvm_observeCollection:(NSString *)keyPath options:(NSKeyValueObservingOptions)options with:(ObserveCollectionBlock)block {
#ifdef DEBUG
    CheckClassKeyPathForPropertiesNotGetters([self class], keyPath);
#endif

    if (!self.mvvm_holder.collectionBlocks[keyPath]) {
        self.mvvm_holder.collectionBlocks[keyPath] = [NSMutableArray array];
    }
    [self.mvvm_holder.collectionBlocks[keyPath] addObject:[block copy]];

    if (self.mvvm_holder.collectionBlocks[keyPath].count == 1) {
        BOOL needInitialCall = (options & NSKeyValueObservingOptionInitial);
        if (needInitialCall) {
            options ^= NSKeyValueObservingOptionInitial;
        }
        [self addObserver:self forKeyPath:keyPath options:options context:MVVMKVOContext];
        if (needInitialCall) {
            block(self, [self valueForKeyPath:keyPath], NSKeyValueChangeSetting, [NSIndexSet indexSet]);
        }
    }
    else if (options | NSKeyValueObservingOptionInitial) {
        block(self, [self valueForKeyPath:keyPath], NSKeyValueChangeSetting, [NSIndexSet indexSet]);
    }
    
    return block;
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

- (void)mvvm_unobserveLast:(NSString *)keyPath {
    if (self.mvvm_holder.blocks[keyPath]) {
        [self.mvvm_holder.blocks[keyPath] removeLastObject];
        if (self.mvvm_holder.blocks[keyPath].count == 0) {
            [self.mvvm_holder.blocks removeObjectForKey:keyPath];
            [self removeObserver:self forKeyPath:keyPath context:MVVMKVOContext];
        }
    }
    
    if (self.mvvm_holder.collectionBlocks[keyPath]) {
        [self.mvvm_holder.collectionBlocks[keyPath] removeLastObject];
        if (self.mvvm_holder.collectionBlocks[keyPath].count == 0) {
            [self.mvvm_holder.collectionBlocks removeObjectForKey:keyPath];
            [self removeObserver:self forKeyPath:keyPath context:MVVMKVOContext];
        }
    }
}

- (void)mvvm_unobserveBlock:(id)block {
    NSString *keyPath = [self.mvvm_holder.blocks allKeysForObject:block].firstObject;
    if (keyPath) {
        [self.mvvm_holder.blocks[keyPath] removeObject:block];
        if (self.mvvm_holder.blocks[keyPath].count == 0) {
            [self.mvvm_holder.blocks removeObjectForKey:keyPath];
            [self removeObserver:self forKeyPath:keyPath context:MVVMKVOContext];
        }
    }
    
    keyPath = [self.mvvm_holder.collectionBlocks allKeysForObject:block].firstObject;
    if (keyPath) {
        [self.mvvm_holder.collectionBlocks[keyPath] removeObject:block];
        if (self.mvvm_holder.collectionBlocks[keyPath].count == 0) {
            [self.mvvm_holder.collectionBlocks removeObjectForKey:keyPath];
            [self removeObserver:self forKeyPath:keyPath context:MVVMKVOContext];
        }
    }
}

- (void)mvvm_unobserveAll {
    if (objc_getAssociatedObject(self, @selector(mvvm_holder))) {
        [self mvvm_unobserveAllWithUnobserver:self.mvvm_holder];
        objc_setAssociatedObject(self, _cmd, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
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

    for (ObserveBlock block in [self.mvvm_holder.blocks[keyPath] copy]) {
        block(self, (newValue != [NSNull null]) ? newValue : nil);
    }
    for (ObserveCollectionBlock block in [self.mvvm_holder.collectionBlocks[keyPath] copy]) {
        block(self, (newValue != [NSNull null]) ? newValue : nil, changeType, indexes);
    }
}

@end
