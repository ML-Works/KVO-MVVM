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

@interface NSObject (KVOMVVMLocking)

@property (assign, nonatomic) BOOL mvvm_skip;
@property (assign, nonatomic) BOOL mvvm_inDealloc;

@end

@implementation NSObject (KVOMVVMLocking)

static NSHashTable *skipHashTable = nil;

- (BOOL)mvvm_skip {
    return [skipHashTable containsObject:self];
}

- (void)setMvvm_skip:(BOOL)mvvm_skip {
    if (!skipHashTable) {
        skipHashTable = [NSHashTable hashTableWithOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)];
    }
    if (mvvm_skip) {
        [skipHashTable addObject:self];
    }
    else {
        [skipHashTable removeObject:self];
    }
}

static NSHashTable *inDeallocHashTable = nil;

- (BOOL)mvvm_inDealloc {
    return [inDeallocHashTable containsObject:self];
}

- (void)setMvvm_inDealloc:(BOOL)mvvm_inDealloc {
    if (!inDeallocHashTable) {
        inDeallocHashTable = [NSHashTable hashTableWithOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)];
    }
    if (mvvm_inDealloc) {
        [inDeallocHashTable addObject:self];
    }
    else {
        [inDeallocHashTable removeObject:self];
    }
}

@end

//

@interface KVOMVVMObserverFriend : NSObject

@property (assign, nonatomic) NSObject *observer;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths;

@end

@implementation KVOMVVMObserverFriend

- (instancetype)initWithObserver:(id)observer {
    self = [super init];
    if (self) {
        _observer = observer;
    }
    return self;
}

- (NSHashTable *)contextsForKeyPath:(NSString *)keyPath object:(id)object {
    return CreateDictionary(&_keyPaths, keyPath, object);
}

- (void)dealloc {
    self.observer.mvvm_inDealloc = YES;
    
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
    
    self.observer.mvvm_inDealloc = NO;
}

@end

//

@implementation NSObject (KVOMVVMObserverFriend)

- (KVOMVVMObserverFriend *)mvvm_friend {
    KVOMVVMObserverFriend *friend = objc_getAssociatedObject(self, _cmd);
    if (friend == nil && !self.mvvm_inDealloc) {
        friend = [[KVOMVVMObserverFriend alloc] initWithObserver:self];
        objc_setAssociatedObject(self, _cmd, friend, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return friend;
}

@end

//

@interface KVOMVVMUnobserver : NSObject

@property (assign, nonatomic) NSObject *object;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths;

@end

@implementation KVOMVVMUnobserver

- (instancetype)initWithObject:(id)object {
    self = [super init];
    if (self) {
        _object = object;
    }
    return self;
}

- (NSHashTable *)contextsForKeyPath:(NSString *)keyPath observer:(id)observer {
    return CreateDictionary(&_keyPaths, keyPath, observer);
}

- (void)dealloc {
    self.object.mvvm_inDealloc = YES;
    
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
    
    self.object.mvvm_inDealloc = NO;
}

@end

//

@implementation NSObject (KVOMVVMUnobservable)

- (KVOMVVMUnobserver *)mvvm_unobserver {
    KVOMVVMUnobserver *unobserver = objc_getAssociatedObject(self, _cmd);
    if (unobserver == nil && !self.mvvm_inDealloc) {
        unobserver = [[KVOMVVMUnobserver alloc] initWithObject:self];
        objc_setAssociatedObject(self, _cmd, unobserver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return unobserver;
}

@end

//

@implementation NSObject (KVOMVVMSwizzling)

+ (void)load {
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
    BOOL skip = self.mvvm_skip;
    if (!skip) {
        {
            KVOMVVMUnobserver *unobserver = self.mvvm_unobserver;
            NSHashTable *hashTable = [unobserver contextsForKeyPath:keyPath observer:observer];
            [hashTable addObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        }
        {
            KVOMVVMObserverFriend *friend = observer.mvvm_friend;
            NSHashTable *hashTable = [friend contextsForKeyPath:keyPath object:self];
            [hashTable addObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        }
    }
    
#if KVO_MVVM_DEBUG_PRINT
    NSLog(@"%p [%@%@ addObserver:%p forKeyPath:%@ context:%p]", self, [self class], skip ? @"(Skip)" :@"", observer, keyPath, context);
#endif

    if (!skip) {
        self.mvvm_skip = YES;
    }
    [self mvvm_addObserver:observer forKeyPath:keyPath options:options context:context];
    if (!skip) {
        self.mvvm_skip = NO;
    }
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context {
    BOOL skip = self.mvvm_skip;
    if (!skip) {
        {
            KVOMVVMUnobserver *unobserver = self.mvvm_unobserver;
            NSHashTable *hashTable = [unobserver.keyPaths[keyPath] objectForKey:observer];
            [hashTable removeObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
            if (hashTable && hashTable.count == 0) {
                [unobserver.keyPaths[keyPath] removeObjectForKey:observer];
            }
        }
        {
            KVOMVVMObserverFriend *friend = observer.mvvm_friend;
            NSHashTable *hashTable = [friend.keyPaths[keyPath] objectForKey:self];
            [hashTable removeObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
            if (hashTable && hashTable.count == 0) {
                [friend.keyPaths[keyPath] removeObjectForKey:self];
            }
        }
    }
    
#if KVO_MVVM_DEBUG_PRINT
    NSLog(@"%p [%@%@ removeObserver:%p forKeyPath:%@ context:%p]", self, [self class], skip ? @"(Skip)" : @"", observer, keyPath, context);
#endif
    
    if (!skip) {
        self.mvvm_skip = YES;
    }
    [self mvvm_removeObserver:observer forKeyPath:keyPath context:context];
    if (!skip) {
        self.mvvm_skip = NO;
    }
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    BOOL skip = self.mvvm_skip;
    if (!skip) {
        {
            KVOMVVMUnobserver *unobserver = self.mvvm_unobserver;
            [unobserver.keyPaths[keyPath] removeObjectForKey:observer];
            if (unobserver.keyPaths[keyPath].count == 0) {
                [unobserver.keyPaths removeObjectForKey:keyPath];
            }
            if (unobserver.keyPaths.count == 0) {
                unobserver.keyPaths = nil;
            }
        }
        {
            KVOMVVMObserverFriend *friend = observer.mvvm_friend;
            [friend.keyPaths[keyPath] removeObjectForKey:self];
            if (friend.keyPaths[keyPath].count == 0) {
                [friend.keyPaths removeObjectForKey:keyPath];
            }
            if (friend.keyPaths.count == 0) {
                friend.keyPaths = nil;
            }
        }
    }
    
#if KVO_MVVM_DEBUG_PRINT
    NSLog(@"%p [%@%@ removeObserver:%p forKeyPath:%@]", self, [self class], skip ? @"(Skip)" : @"", observer, keyPath);
#endif
    
    if (!skip) {
        self.mvvm_skip = YES;
    }
    [self mvvm_removeObserver:observer forKeyPath:keyPath];
    if (!skip) {
        self.mvvm_skip = NO;
    }
}

@end
