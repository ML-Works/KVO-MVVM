//
//  SimpleKVOTests.m
//  KVO-MVVM
//
//  Created by Anton Bukov on 30.08.16.
//  Copyright © 2016 Anton Bukov. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <KVO-MVVM/KVONSObject.h>

//

@interface SimpleKVOModel : NSObject

@property (strong, nonatomic) NSArray *array;

@end

@implementation SimpleKVOModel

@end

@interface SimpleKVO : KVONSObject

@property (strong, nonatomic) SimpleKVOModel *viewModel;
@property (assign, nonatomic) BOOL observerWasCalled;
@property (assign, nonatomic) BOOL observerWasCalled2;

@end

@implementation SimpleKVO

- (instancetype)init {
    self = [super init];
    if (self) {
        [self mvvm_observe:@"viewModel.array" with:^(typeof(self) self, NSArray * value) {
            self.observerWasCalled2 = YES;
        }];
        [self addObserver:self forKeyPath:@"viewModel.array" options:(NSKeyValueObservingOptionNew) context:NULL];
    }
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"viewModel.array" context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    if ([keyPath isEqualToString:@"viewModel.array"] && object == self) {
        self.observerWasCalled = YES;
    }
}

@end

//

@interface SimpleKVOTests : XCTestCase

@end

@implementation SimpleKVOTests

- (void)testSimpleKVONotBroken {
    @autoreleasepool {
        SimpleKVO *object = [SimpleKVO new];
        object.viewModel = [SimpleKVOModel new];
        object.viewModel.array = @[ @1 ];

        XCTAssertTrue(object.observerWasCalled);
        XCTAssertTrue(object.observerWasCalled2);
    }
}

@end
