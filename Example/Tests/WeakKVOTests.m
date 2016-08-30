//
//  WeakKVOTests.m
//  KVO-MVVM
//
//  Created by Anton Bukov on 30.08.16.
//  Copyright © 2016 Anton Bukov. All rights reserved.
//

#import <XCTest/XCTest.h>

//

@interface WeakKVOModel : NSObject

@property (strong, nonatomic) NSNumber *number;

@end

@implementation WeakKVOModel

@end

@interface WeakKVO : NSObject

@property (weak, nonatomic) WeakKVOModel *viewModel;
@property (assign, nonatomic) BOOL observerWasCalled;

@end

@implementation WeakKVO

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addObserver:self forKeyPath:@"viewModel.number" options:(NSKeyValueObservingOptionNew) context:NULL];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"viewModel.number"] && object == self) {
        self.observerWasCalled = YES;
    }
}

@end

//

@interface WeakKVOTests : XCTestCase

@end

@implementation WeakKVOTests

- (void)testSimpleKVONotBroken {
    WeakKVO *object = [WeakKVO new];
    
    @autoreleasepool {
        WeakKVOModel *model = [WeakKVOModel new];
        object.viewModel = model;
        object.viewModel.number = @1;
    }
    
    XCTAssertTrue(object.observerWasCalled);
}

@end
