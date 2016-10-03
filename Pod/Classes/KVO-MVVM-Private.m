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

//

static NSMapTable *skipDict = nil;
__attribute__((constructor))
static void initialize_unobservers() {
    skipDict = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality) valueOptions:NSPointerFunctionsStrongMemory];
}

//

@class KVOMVVMUnobserver;

@interface NSObject (KVOMVVMUnobservable)

@property (readonly, strong, nonatomic) KVOMVVMUnobserver *mvvm_unobserver;
@property (assign, nonatomic) BOOL mvvm_skipObserverCalls;
- (void)mvvm_skipObserverCallsForget;

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;
- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context;

@end

//

@interface KVOMVVMUnobserver : NSObject

@property (assign, nonatomic) NSObject *object;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *strongKeyPaths;

@end

@implementation KVOMVVMUnobserver

- (instancetype)initWithObject:(id)object {
    self = [super init];
    if (self) {
        _object = object;
    }
    return self;
}

+ (NSHashTable *)createDictionary:(NSMutableDictionary * __strong *)dict
                       forKeyPath:(NSString *)keyPath
                         observer:(id)observer
             storeObserversStrong:(BOOL)storeObserversStrong {
    if (!*dict) {
        *dict = [NSMutableDictionary dictionary];
    }
    NSMapTable<id, NSHashTable *> *mapTable = (*dict)[keyPath];
    if (!mapTable) {
        mapTable = [NSMapTable mapTableWithKeyOptions:storeObserversStrong ? NSPointerFunctionsStrongMemory : (NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality) valueOptions:NSPointerFunctionsStrongMemory];
        (*dict)[keyPath] = mapTable;
    }
    NSHashTable *hashTable = [mapTable objectForKey:observer];
    if (!hashTable) {
        hashTable = [NSHashTable hashTableWithOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)];
        [mapTable setObject:hashTable forKey:observer];
    }
    return hashTable;
}

- (NSHashTable *)contextsForKeyPath:(NSString *)keyPath observer:(id)observer {
    @autoreleasepool {
        return [[self class] createDictionary:&_keyPaths forKeyPath:keyPath observer:observer storeObserversStrong:NO];
    }
}

- (NSHashTable *)contextsForStrongKeyPath:(NSString *)keyPath observer:(id)observer {
    @autoreleasepool {
        return [[self class] createDictionary:&_strongKeyPaths forKeyPath:keyPath observer:observer storeObserversStrong:YES];
    }
}

- (void)dealloc {
    @autoreleasepool {
        self.object.mvvm_skipObserverCalls = YES;
        for (NSDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths in @[ self.keyPaths ?: @{}, self.strongKeyPaths ?: @{} ]) {
            for (NSString *keyPath in keyPaths) {
                NSMapTable<id, NSHashTable *> *observers = keyPaths[keyPath];
                for (NSObject *observer in observers) {
                    for (id context in [observers objectForKey:observer] ) {
                        if (context != KVOMVVMUnobserverContext) {
#if KVO_MVVM_DEBUG_PRINT
                            NSLog(@"[%@(KVO-MVVM) removeObserver:%p forKeyPath:%@ context:%p]", [self.object class], observer, keyPath, context);
#endif
                            [self.object mvvm_removeObserver:observer forKeyPath:keyPath context:(__bridge void *_Nullable)(context)];
                        }
                        else {
#if KVO_MVVM_DEBUG_PRINT
                            NSLog(@"[%@(KVO-MVVM) removeObserver:%p forKeyPath:%@]", [self.object class], observer, keyPath);
#endif
                            [self.object mvvm_removeObserver:observer forKeyPath:keyPath];
                        }
                    }
                }
            }
        }
        [self mvvm_skipObserverCallsForget];
        objc_removeAssociatedObjects(self.object);
    }
}

@end

//

@implementation NSObject (KVOMVVMUnobservable)

- (BOOL)mvvm_skipObserverCalls {
    @synchronized (skipDict) {
        return [[skipDict objectForKey:self] boolValue];
    }
}

- (void)setMvvm_skipObserverCalls:(BOOL)mvvm_skipObserverCalls {
    @synchronized (skipDict) {
        [skipDict setObject:@(mvvm_skipObserverCalls) forKey:self];
    }
}

- (void)mvvm_skipObserverCallsForget {
    @synchronized (skipDict) {
        [skipDict removeObjectForKey:self];
    }
}

- (KVOMVVMUnobserver *)mvvm_unobserver {
    KVOMVVMUnobserver *unobserver;
    @autoreleasepool {
        unobserver = objc_getAssociatedObject(self, _cmd);
        if (unobserver == nil) {
            unobserver = [[KVOMVVMUnobserver alloc] initWithObject:self];
            objc_setAssociatedObject(self, _cmd, unobserver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return unobserver;
}

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
    @autoreleasepool {
        if (self.mvvm_skipObserverCalls) {
#if KVO_MVVM_DEBUG_PRINT
            NSLog(@"[%@(KVO-MVVM-Skipped) addObserver:%p forKeyPath:%@ context:%p]", [self class], observer, keyPath, context);
#endif
            [self mvvm_addObserver:observer forKeyPath:keyPath options:options context:context];
            return;
        }
        
#if KVO_MVVM_DEBUG_PRINT
        NSLog(@"[%@ addObserver:%p forKeyPath:%@ context:%p]", [self class], observer, keyPath, context);
#endif
        KVOMVVMUnobserver *unobserver = self.mvvm_unobserver;
        if ([observer isKindOfClass:NSClassFromString(@"NSKeyValueObservance")]) {
            NSHashTable *strongHashTable = [unobserver contextsForStrongKeyPath:keyPath observer:observer];
            [strongHashTable addObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        }
        else {
            NSHashTable *hashTable = [unobserver contextsForKeyPath:keyPath observer:observer];
            [hashTable addObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        }
        
        self.mvvm_skipObserverCalls = YES;
        [self mvvm_addObserver:observer forKeyPath:keyPath options:options context:context];
        self.mvvm_skipObserverCalls = NO;
    }
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context {
    @autoreleasepool {
        if (self.mvvm_skipObserverCalls) {
#if KVO_MVVM_DEBUG_PRINT
            NSLog(@"[%@(KVO-MVVM-Skipped) removeObserver:%p forKeyPath:%@ context:%p]", [self class], observer, keyPath, context);
#endif
            [self mvvm_removeObserver:observer forKeyPath:keyPath context:context];
            return;
        }
        
#if KVO_MVVM_DEBUG_PRINT
        NSLog(@"[%@ removeObserver:%p forKeyPath:%@ context:%p]", [self class], observer, keyPath, context);
#endif
        KVOMVVMUnobserver *unobserver = self.mvvm_unobserver;
        NSHashTable *hashTable = [unobserver.keyPaths[keyPath] objectForKey:observer];
        NSHashTable *strongHashTable = [unobserver.strongKeyPaths[keyPath] objectForKey:observer];
        [hashTable removeObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        [strongHashTable removeObject:(__bridge id _Nullable)(context ?: KVOMVVMUnobserverContext)];
        if (hashTable && hashTable.count == 0) {
            [unobserver.keyPaths[keyPath] removeObjectForKey:observer];
        }
        if (strongHashTable && strongHashTable.count == 0) {
            [unobserver.strongKeyPaths[keyPath] removeObjectForKey:observer];
        }
        
        self.mvvm_skipObserverCalls = YES;
        [self mvvm_removeObserver:observer forKeyPath:keyPath context:context];
        self.mvvm_skipObserverCalls = NO;
    }
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    @autoreleasepool {
        if (self.mvvm_skipObserverCalls) {
#if KVO_MVVM_DEBUG_PRINT
            NSLog(@"[%@(KVO-MVVM-Skipped) removeObserver:%p forKeyPath:%@]", [self class], observer, keyPath);
#endif
            [self mvvm_removeObserver:observer forKeyPath:keyPath];
            return;
        }
        
#if KVO_MVVM_DEBUG_PRINT
        NSLog(@"[%@ removeObserver:%p forKeyPath:%@]", [self class], observer, keyPath);
#endif
        KVOMVVMUnobserver *unobserver = self.mvvm_unobserver;
        [unobserver.keyPaths[keyPath] removeObjectForKey:observer];
        [unobserver.strongKeyPaths[keyPath] removeObjectForKey:observer];
        if (unobserver.keyPaths[keyPath].count == 0) {
            [unobserver.keyPaths removeObjectForKey:keyPath];
        }
        if (unobserver.strongKeyPaths[keyPath].count == 0) {
            [unobserver.strongKeyPaths removeObjectForKey:keyPath];
        }
        if (unobserver.keyPaths.count == 0) {
            unobserver.keyPaths = nil;
        }
        if (unobserver.strongKeyPaths.count == 0) {
            unobserver.strongKeyPaths = nil;
        }
        
        self.mvvm_skipObserverCalls = YES;
        [self mvvm_removeObserver:observer forKeyPath:keyPath];
        self.mvvm_skipObserverCalls = NO;
    }
}

@end
