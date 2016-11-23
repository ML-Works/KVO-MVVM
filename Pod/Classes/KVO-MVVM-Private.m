//
//  KVO-MVVM-Private.m
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

#import <objc/runtime.h>

#import <JRSwizzle/JRSwizzle.h>

#import "MLWHashTableMissings.h"

//

#define KVO_MVVM_DEBUG_PRINT 0

static void *KVOMVVMUnobserverContext = &KVOMVVMUnobserverContext;

static NSHashTable *CreateDictionary(NSMutableDictionary * __strong *dict, NSString *keyPath, id observerOrObject) {
    if (!*dict) {
        *dict = [NSMutableDictionary dictionary];
    }
    NSMapTable<id, NSHashTable *> *mapTable = (*dict)[keyPath];
    if (!mapTable) {
        mapTable = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality) valueOptions:NSPointerFunctionsStrongMemory];
        (*dict)[keyPath] = mapTable;
    }
    NSHashTable *hashTable = [mapTable objectForKey:observerOrObject];
    if (!hashTable) {
        hashTable = [NSHashTable hashTableWithOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)];
        [mapTable setObject:hashTable forKey:observerOrObject];
    }
    return hashTable;
}

//

//
// TODO:
// Conditional use unfair_lock instead of dispatch_semaphore_t on iOS 10+
//

static NSMapTable *skipMapTable;
static volatile dispatch_semaphore_t skipMapTableLock;

static void *skipContext(void *self) {
    dispatch_semaphore_wait(skipMapTableLock, DISPATCH_TIME_FOREVER);
    void *result = MLWMapGet(skipMapTable, self);
    dispatch_semaphore_signal(skipMapTableLock);
    return result;
}

static void setSkipContext(void *self, void *skipContext) {
    dispatch_semaphore_wait(skipMapTableLock, DISPATCH_TIME_FOREVER);
    if (skipContext) {
        MLWMapInsert(skipMapTable, self, skipContext);
    }
    else {
        MLWMapRemove(skipMapTable, self);
    }
    dispatch_semaphore_signal(skipMapTableLock);
}

static NSHashTable *inDeallocHashTable = nil;
static volatile dispatch_semaphore_t inDeallocHashTableLock;

static BOOL inDealloc(void *self) {
    dispatch_semaphore_wait(inDeallocHashTableLock, DISPATCH_TIME_FOREVER);
    BOOL result = MLWHashGet(inDeallocHashTable, self);
    dispatch_semaphore_signal(inDeallocHashTableLock);
    return result;
}

static void setInDealloc(void *self, BOOL inDealloc) {
    dispatch_semaphore_wait(inDeallocHashTableLock, DISPATCH_TIME_FOREVER);
    if (inDealloc) {
        MLWHashInsert(inDeallocHashTable, self);
    }
    else {
        MLWHashRemove(inDeallocHashTable, self);
    }
    dispatch_semaphore_signal(inDeallocHashTableLock);
}

//

@interface KVOMVVMObserverFriend : NSObject {
    @public
    volatile dispatch_semaphore_t _mvvm_lock;
}

@property (assign, nonatomic) NSObject *observer;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths;

@end

@implementation KVOMVVMObserverFriend

- (instancetype)initWithObserver:(id)observer {
    self = [super init];
    if (self) {
        _mvvm_lock = dispatch_semaphore_create(1);
        _observer = observer;
    }
    return self;
}

- (NSHashTable *)contextsForKeyPath:(NSString *)keyPath object:(id)object {
    return CreateDictionary(&_keyPaths, keyPath, object);
}

- (void)dealloc {
    setInDealloc((__bridge void *)_observer, YES);
    
    for (NSString *keyPath in self.keyPaths) {
        NSMapTable<id, NSHashTable *> *objects = self.keyPaths[keyPath];
        for (NSObject *object in objects) {
            if (self.observer == object) {
                continue; // Avoid double unobserving
            }
            
            for (id context in [objects objectForKey:object] ) {
                if (context != KVOMVVMUnobserverContext) {
#if KVO_MVVM_DEBUG_PRINT
                    NSLog(@"%p [%@(KVO-MVVM-Friend) removeObserver:%p forKeyPath:%@ context:%p]", object, [object class], self.observer, keyPath, context);
#endif
                    [object removeObserver:self.observer forKeyPath:keyPath context:(__bridge void *_Nullable)(context)];
                }
                else {
#if KVO_MVVM_DEBUG_PRINT
                    NSLog(@"%p [%@(KVO-MVVM-Friend) removeObserver:%p forKeyPath:%@]", object, [object class], self.observer, keyPath);
#endif
                    [object removeObserver:self.observer forKeyPath:keyPath];
                }
            }
        }
    }
    
    setInDealloc((__bridge void *)_observer, NO);
}

@end

//

@implementation NSObject (KVOMVVMObserverFriend)

- (KVOMVVMObserverFriend *)mvvm_friend {
    @synchronized (self) {
        KVOMVVMObserverFriend *observerFriend = objc_getAssociatedObject(self, _cmd);
        if (observerFriend == nil && !inDealloc((__bridge void *)self)) {
            observerFriend = [[KVOMVVMObserverFriend alloc] initWithObserver:self];
            objc_setAssociatedObject(self, _cmd, observerFriend, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return observerFriend;
    }
}

@end

//

@interface KVOMVVMUnobserver : NSObject {
    @public
    volatile dispatch_semaphore_t _mvvm_lock;
}

@property (assign, nonatomic) NSObject *object;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths;

@end

@implementation KVOMVVMUnobserver

- (instancetype)initWithObject:(id)object {
    self = [super init];
    if (self) {
        _mvvm_lock = dispatch_semaphore_create(1);
        _object = object;
    }
    return self;
}

- (NSHashTable *)contextsForKeyPath:(NSString *)keyPath observer:(id)observer {
    return CreateDictionary(&_keyPaths, keyPath, observer);
}

- (void)dealloc {
    setInDealloc((__bridge void *)_object, YES);
    
    for (NSString *keyPath in self.keyPaths) {
        NSMapTable<id, NSHashTable *> *observers = self.keyPaths[keyPath];
        for (NSObject *observer in observers) {
            for (id context in [observers objectForKey:observer] ) {
                if (context != KVOMVVMUnobserverContext) {
#if KVO_MVVM_DEBUG_PRINT
                    NSLog(@"%p [%@(KVO-MVVM) removeObserver:%p forKeyPath:%@ context:%p]", self.object, [self.object class], observer, keyPath, context);
#endif
                    [self.object removeObserver:observer forKeyPath:keyPath context:(__bridge void *_Nullable)(context)];
                }
                else {
#if KVO_MVVM_DEBUG_PRINT
                    NSLog(@"%p [%@(KVO-MVVM) removeObserver:%p forKeyPath:%@]", self.object, [self.object class], observer, keyPath);
#endif
                    [self.object removeObserver:observer forKeyPath:keyPath];
                }
            }
        }
    }
    
    setInDealloc((__bridge void *)_object, NO);
}

@end

//

@implementation NSObject (KVOMVVMUnobservable)

- (KVOMVVMUnobserver *)mvvm_unobserver {
    @synchronized (self) {
        KVOMVVMUnobserver *unobserver = objc_getAssociatedObject(self, _cmd);
        if (unobserver == nil && !inDealloc((__bridge void *)self)) {
            unobserver = [[KVOMVVMUnobserver alloc] initWithObject:self];
            objc_setAssociatedObject(self, _cmd, unobserver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return unobserver;
    }
}

@end

//

@implementation NSObject (KVOMVVMSwizzling)

+ (void)load {
    skipMapTableLock = dispatch_semaphore_create(1);
    inDeallocHashTableLock = dispatch_semaphore_create(1);
    
    skipMapTable = [[NSMapTable alloc] initWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality) valueOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality) capacity:100];
    inDeallocHashTable = [[NSHashTable alloc] initWithOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality) capacity:100];
    
    NSError *error;
    if (![self jr_swizzleMethod:@selector(addObserver:forKeyPath:options:context:) withMethod:@selector(mvvm_addObserver:forKeyPath:options:context:) error:&error]) {
        NSLog(@"Swizzling [%@ %@] error: %@", self, NSStringFromSelector(@selector(addObserver:forKeyPath:options:context:)), error);
    }

    if (![self jr_swizzleMethod:@selector(removeObserver:forKeyPath:context:) withMethod:@selector(mvvm_removeObserver:forKeyPath:context:) error:&error]) {
        NSLog(@"Swizzling [%@ %@] error: %@", self, NSStringFromSelector(@selector(removeObserver:forKeyPath:context:)), error);
    }

    if (![self jr_swizzleMethod:@selector(removeObserver:forKeyPath:) withMethod:@selector(mvvm_removeObserver:forKeyPath:) error:&error]) {
        NSLog(@"Swizzling [%@ %@] error: %@", self, NSStringFromSelector(@selector(removeObserver:forKeyPath:)), error);
    }
}

- (void)mvvm_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
    KVOMVVMUnobserver *unobserver = self.mvvm_unobserver;
    if (unobserver) {
        dispatch_semaphore_wait(unobserver->_mvvm_lock, DISPATCH_TIME_FOREVER);
        NSHashTable *hashTable = [unobserver contextsForKeyPath:keyPath observer:observer];
        [hashTable addObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        dispatch_semaphore_signal(unobserver->_mvvm_lock);
    }
    KVOMVVMObserverFriend *observerFriend = observer.mvvm_friend;
    if (observerFriend) {
        dispatch_semaphore_wait(observerFriend->_mvvm_lock, DISPATCH_TIME_FOREVER);
        NSHashTable *hashTable = [observerFriend contextsForKeyPath:keyPath object:self];
        [hashTable addObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        dispatch_semaphore_signal(observerFriend->_mvvm_lock);
    }
    
#if KVO_MVVM_DEBUG_PRINT
    NSLog(@"%p [%@%@ addObserver:%p forKeyPath:%@ context:%p]", self, [self class], skipContext((__bridge void *)(self)) ? @"(Inner)" : @"", observer, keyPath, context);
#endif

    [self mvvm_addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context {
    KVOMVVMUnobserver *unobserver = self.mvvm_unobserver;
    if (unobserver) {
        dispatch_semaphore_wait(unobserver->_mvvm_lock, DISPATCH_TIME_FOREVER);
        NSHashTable *hashTable = [unobserver.keyPaths[keyPath] objectForKey:observer];
        [hashTable removeObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        if (hashTable && hashTable.count == 0) {
            [unobserver.keyPaths[keyPath] removeObjectForKey:observer];
        }
        if (unobserver.keyPaths.count == 0) {
            unobserver.keyPaths = nil;
        }
        dispatch_semaphore_signal(unobserver->_mvvm_lock);
    }
    KVOMVVMObserverFriend *observerFriend = observer.mvvm_friend;
    if (observerFriend) {
        dispatch_semaphore_wait(observerFriend->_mvvm_lock, DISPATCH_TIME_FOREVER);
        NSHashTable *hashTable = [observerFriend.keyPaths[keyPath] objectForKey:self];
        [hashTable removeObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        if (hashTable && hashTable.count == 0) {
            [observerFriend.keyPaths[keyPath] removeObjectForKey:self];
        }
        if (observerFriend.keyPaths.count == 0) {
            observerFriend.keyPaths = nil;
        }
        dispatch_semaphore_signal(observerFriend->_mvvm_lock);
    }
    
#if KVO_MVVM_DEBUG_PRINT
    NSLog(@"%p [%@%@ removeObserver:%p forKeyPath:%@ context:%p]", self, [self class], skipContext((__bridge void *)(self)) ? @"(Inner)" : @"", observer, keyPath, context);
#endif
    
    void *prev_context = skipContext((__bridge void *)self);
    setSkipContext((__bridge void *)self, context);
    [self mvvm_removeObserver:observer forKeyPath:keyPath context:context];
    setSkipContext((__bridge void *)self, prev_context);
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    void *context = skipContext((__bridge void *)self);
    KVOMVVMUnobserver *unobserver = self.mvvm_unobserver;
    if (unobserver) {
        dispatch_semaphore_wait(unobserver->_mvvm_lock, DISPATCH_TIME_FOREVER);
        NSHashTable *hashTable = [unobserver.keyPaths[keyPath] objectForKey:observer];
        [hashTable removeObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        [unobserver.keyPaths[keyPath] removeObjectForKey:observer];
        if (unobserver.keyPaths.count == 0) {
            unobserver.keyPaths = nil;
        }
        dispatch_semaphore_signal(unobserver->_mvvm_lock);
    }
    KVOMVVMObserverFriend *observerFriend = observer.mvvm_friend;
    if (observerFriend) {
        dispatch_semaphore_wait(observerFriend->_mvvm_lock, DISPATCH_TIME_FOREVER);
        NSHashTable *hashTable = [observerFriend.keyPaths[keyPath] objectForKey:self];
        [hashTable removeObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        [observerFriend.keyPaths[keyPath] removeObjectForKey:self];
        if (observerFriend.keyPaths.count == 0) {
            observerFriend.keyPaths = nil;
        }
        dispatch_semaphore_signal(observerFriend->_mvvm_lock);
    }
    
#if KVO_MVVM_DEBUG_PRINT
    NSLog(@"%p [%@%@ removeObserver:%p forKeyPath:%@]", self, [self class], skipContext((__bridge void *)(self)) ? @"(Inner)" : @"", observer, keyPath);
#endif
    
    [self mvvm_removeObserver:observer forKeyPath:keyPath];
}

@end
