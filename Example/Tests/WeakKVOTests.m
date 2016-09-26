//
//  WeakKVOTests.m
//  KVO-MVVM
//
//  Created by Anton Bukov on 30.08.16.
//  Copyright © 2016 Anton Bukov. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <KVO-MVVM/KVO-MVVM.h>

//

@interface WeakKVOModel : NSObject

@property (strong, nonatomic) NSArray *array;

@end

@implementation WeakKVOModel

@end

@interface WeakKVO : NSObject

@property (weak, nonatomic) WeakKVOModel *viewModel;
@property (assign, nonatomic) BOOL observerWasCalled;
@property (assign, nonatomic) BOOL observerWasCalled2;

@end

@implementation WeakKVO

- (instancetype)init {
    self = [super init];
    if (self) {
        [self mvvm_observe:@"viewModel.array" with:^(typeof(self) self, NSNumber * value) {
            self.observerWasCalled2 = YES;
        }];
        [self addObserver:self forKeyPath:@"viewModel.array" options:(NSKeyValueObservingOptionNew) context:NULL];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    if ([keyPath isEqualToString:@"viewModel.array"] && object == self) {
        self.observerWasCalled = YES;
    }
}

@end

//

@interface WeakKVOTests : XCTestCase

@end

@implementation WeakKVOTests

- (void)testWeakKVO {
    @autoreleasepool {
        WeakKVO *object = [WeakKVO new];

        @autoreleasepool {
            WeakKVOModel *model = [WeakKVOModel new];
            object.viewModel = model;
            object.viewModel.array = @[ @1 ];
        }

        XCTAssertTrue(object.observerWasCalled);
        XCTAssertTrue(object.observerWasCalled2);
    }
}

@end
