//
//  KVO-MVVM-Unobserver.m
//  Pods
//
//  Created by Anton Bukov on 30.08.16.
//
//

#import <objc/runtime.h>

#import <JRSwizzle/JRSwizzle.h>

#import "NSObject+MLWKVOMVVMUnobserver.h"

//

@interface MLWKVOMVVMUnobserver : NSObject

@property (assign, nonatomic) id object;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSHashTable<NSObject *> *> *keyPaths;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSHashTable<NSObject *> *> *strongKeyPaths;

@end

@implementation MLWKVOMVVMUnobserver

- (NSMutableDictionary<NSString *, NSHashTable<NSObject *> *> *)keyPaths {
    if (_keyPaths == nil) {
        _keyPaths = [NSMutableDictionary dictionary];
    }
    return _keyPaths;
}

- (NSMutableDictionary<NSString *, NSHashTable<NSObject *> *> *)strongKeyPaths {
    if (_strongKeyPaths == nil) {
        _strongKeyPaths = [NSMutableDictionary dictionary];
    }
    return _strongKeyPaths;
}

- (void)dealloc {
    for (NSString *keyPath in self.keyPaths) {
        NSHashTable<NSObject *> *observers = self.keyPaths[keyPath];
        for (NSObject *observer in observers) {
            [self.object removeObserver:observer forKeyPath:keyPath];
        }
    }
    self.keyPaths = nil;

    for (NSString *keyPath in self.strongKeyPaths) {
        NSHashTable<NSObject *> *observers = self.strongKeyPaths[keyPath];
        for (NSObject *observer in observers) {
            [self.object removeObserver:observer forKeyPath:keyPath];
        }
    }
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
        unobserver = [[MLWKVOMVVMUnobserver alloc] init];
        unobserver.object = self;
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
    if ([observer isKindOfClass:NSClassFromString(@"NSKeyValueObservance")]) {
        if (!self.mvvm_unobserver.strongKeyPaths[keyPath]) {
            self.mvvm_unobserver.strongKeyPaths[keyPath] = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory];
        }
        [self.mvvm_unobserver.strongKeyPaths[keyPath] addObject:observer];
    }
    else {
        if (!self.mvvm_unobserver.keyPaths[keyPath]) {
            self.mvvm_unobserver.keyPaths[keyPath] = [NSHashTable hashTableWithOptions:NSPointerFunctionsOpaqueMemory];
        }
        [self.mvvm_unobserver.keyPaths[keyPath] addObject:observer];
    }
    [self mvvm_addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context {
    [self.mvvm_unobserver.keyPaths[keyPath] removeObject:observer];
    [self.mvvm_unobserver.strongKeyPaths[keyPath] removeObject:observer];
    [self mvvm_removeObserver:observer forKeyPath:keyPath context:context];
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    [self.mvvm_unobserver.keyPaths[keyPath] removeObject:observer];
    [self.mvvm_unobserver.strongKeyPaths[keyPath] removeObject:observer];
    [self mvvm_removeObserver:observer forKeyPath:keyPath];
}

@end
