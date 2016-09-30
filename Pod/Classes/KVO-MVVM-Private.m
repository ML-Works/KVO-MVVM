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

static void *MLWKVOMVVMUnobserverContext = &MLWKVOMVVMUnobserverContext;

//

@interface MLWKVOMVVMUnobserver : NSObject

@property (assign, nonatomic) id object;
@property (assign, nonatomic) BOOL skipObserverCalls;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *strongKeyPaths;

@end

@implementation MLWKVOMVVMUnobserver

- (instancetype)initWithObject:(id)object {
    self = [super init];
    if (self) {
        _object = object;
    }
    return self;
}

- (NSHashTable *)contextsForKeyPath:(NSString *)keyPath observer:(id)observer {
    if (!self.keyPaths) {
        self.keyPaths = [NSMutableDictionary dictionary];
    }
    NSMapTable<id, NSHashTable *> *mapTable = self.keyPaths[keyPath];
    if (!mapTable) {
        mapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory valueOptions:NSPointerFunctionsStrongMemory];
        self.keyPaths[keyPath] = mapTable;
    }
    NSHashTable *hashTable = [mapTable objectForKey:observer];
    if (!hashTable) {
        hashTable = [NSHashTable hashTableWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality];
        [mapTable setObject:hashTable forKey:observer];
    }
    return hashTable;
}

- (NSHashTable *)contextsForStrongKeyPath:(NSString *)keyPath observer:(id)observer {
    if (!self.strongKeyPaths) {
        self.strongKeyPaths = [NSMutableDictionary dictionary];
    }
    NSMapTable<id, NSHashTable *> *mapTable = self.strongKeyPaths[keyPath];
    if (!mapTable) {
        mapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
        self.strongKeyPaths[keyPath] = mapTable;
    }
    NSHashTable *hashTable = [mapTable objectForKey:observer];
    if (!hashTable) {
        hashTable = [NSHashTable hashTableWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality];
        [mapTable setObject:hashTable forKey:observer];
    }
    return hashTable;
}

- (void)dealloc {
    for (NSDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths in @[ self.keyPaths ?: @{}, self.strongKeyPaths ?: @{} ]) {
        for (NSString *keyPath in keyPaths) {
            NSMapTable<id, NSHashTable *> *observers = keyPaths[keyPath];
            for (NSObject *observer in observers) {
                for (id context in [observers objectForKey:observer] ) {
                    if (context != MLWKVOMVVMUnobserverContext) {
#if KVO_MVVM_DEBUG_PRINT
                        NSLog(@"[%@(KVO-MVVM) removeObserver:%p forKeyPath:%@ context:%p]", [self.object class], observer, keyPath, context);
#endif
                        [self.object removeObserver:observer forKeyPath:keyPath context:(__bridge void *_Nullable)(context)];
                    }
                    else {
#if KVO_MVVM_DEBUG_PRINT
                        NSLog(@"[%@(KVO-MVVM) removeObserver:%p forKeyPath:%@]", [self.object class], observer, keyPath);
#endif
                        [self.object removeObserver:observer forKeyPath:keyPath];
                    }
                }
            }
        }
    }
    self.keyPaths = nil;
    self.strongKeyPaths = nil;
}

@end

//

@interface NSObject (MLWKVOMVVMUnobservable)

@property (readonly, nonatomic) MLWKVOMVVMUnobserver *mvvm_unobserver;

@end

@implementation NSObject (MLWKVOMVVMUnobservable)

@dynamic mvvm_unobserver;

- (id)mvvm_unobserver {
    MLWKVOMVVMUnobserver *unobserver = objc_getAssociatedObject(self, _cmd);
    if (unobserver == nil) {
        unobserver = [[MLWKVOMVVMUnobserver alloc] initWithObject:self];
        objc_setAssociatedObject(self, _cmd, unobserver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    if (self.mvvm_unobserver.skipObserverCalls) {
#if KVO_MVVM_DEBUG_PRINT
        NSLog(@"[%@(KVO-MVVM-Skipped) addObserver:%p forKeyPath:%@ context:%p]", [self class], observer, keyPath, context);
#endif
        [self mvvm_addObserver:observer forKeyPath:keyPath options:options context:context];
        return;
    }
    
#if KVO_MVVM_DEBUG_PRINT
    NSLog(@"[%@ addObserver:%p forKeyPath:%@ context:%p]", [self class], observer, keyPath, context);
#endif
    if ([observer isKindOfClass:NSClassFromString(@"NSKeyValueObservance")]) {
        NSHashTable *strongHashTable = [self.mvvm_unobserver contextsForStrongKeyPath:keyPath observer:observer];
        [strongHashTable addObject:(__bridge id _Nullable)(context ?: MLWKVOMVVMUnobserverContext)];
    }
    else {
        NSHashTable *hashTable = [self.mvvm_unobserver contextsForKeyPath:keyPath observer:observer];
        [hashTable addObject:(__bridge id _Nullable)(context ?: MLWKVOMVVMUnobserverContext)];
    }
    
    self.mvvm_unobserver.skipObserverCalls = YES;
    [self mvvm_addObserver:observer forKeyPath:keyPath options:options context:context];
    self.mvvm_unobserver.skipObserverCalls = NO;
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context {
    if (self.mvvm_unobserver.skipObserverCalls) {
#if KVO_MVVM_DEBUG_PRINT
        NSLog(@"[%@(KVO-MVVM-Skipped) removeObserver:%p forKeyPath:%@ context:%p]", [self class], observer, keyPath, context);
#endif
        [self mvvm_removeObserver:observer forKeyPath:keyPath context:context];
        return;
    }
    
#if KVO_MVVM_DEBUG_PRINT
    NSLog(@"[%@ removeObserver:%p forKeyPath:%@ context:%p]", [self class], observer, keyPath, context);
#endif
    NSHashTable *hashTable = [self.mvvm_unobserver.keyPaths[keyPath] objectForKey:observer];
    NSHashTable *strongHashTable = [self.mvvm_unobserver.strongKeyPaths[keyPath] objectForKey:observer];
    [hashTable removeObject:(__bridge id _Nullable)(context ?: MLWKVOMVVMUnobserverContext)];
    [strongHashTable removeObject:(__bridge id _Nullable)(context ?: MLWKVOMVVMUnobserverContext)];
    if (hashTable && hashTable.count == 0) {
        [self.mvvm_unobserver.keyPaths[keyPath] removeObjectForKey:observer];
    }
    if (strongHashTable && strongHashTable.count == 0) {
        [self.mvvm_unobserver.strongKeyPaths[keyPath] removeObjectForKey:observer];
    }
    
    self.mvvm_unobserver.skipObserverCalls = YES;
    [self mvvm_removeObserver:observer forKeyPath:keyPath context:context];
    self.mvvm_unobserver.skipObserverCalls = NO;
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    if (self.mvvm_unobserver.skipObserverCalls) {
#if KVO_MVVM_DEBUG_PRINT
        NSLog(@"[%@(KVO-MVVM-Skipped) removeObserver:%p forKeyPath:%@]", [self class], observer, keyPath);
#endif
        [self mvvm_removeObserver:observer forKeyPath:keyPath];
        return;
    }
    
#if KVO_MVVM_DEBUG_PRINT
    NSLog(@"[%@ removeObserver:%p forKeyPath:%@]", [self class], observer, keyPath);
#endif
    [self.mvvm_unobserver.keyPaths[keyPath] removeObjectForKey:observer];
    [self.mvvm_unobserver.strongKeyPaths[keyPath] removeObjectForKey:observer];
    
    self.mvvm_unobserver.skipObserverCalls = YES;
    [self mvvm_removeObserver:observer forKeyPath:keyPath];
    self.mvvm_unobserver.skipObserverCalls = NO;
}

@end
