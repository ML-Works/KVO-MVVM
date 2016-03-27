//
//  KVO-MVVMTests.m
//  KVO-MVVMTests
//
//  Created by Anton Bukov on 03/16/2016.
//  Copyright (c) 2016 Anton Bukov. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <KVO-MVVM/KVO-MVVM.h>

@interface MVVMCycleModelObject : NSObject

@property (assign, nonatomic) NSInteger state;

@end

@implementation MVVMCycleModelObject

@end

//

@interface MVVMCycleView : MVVMView

@property (strong, nonatomic) MVVMCycleModelObject *viewModel;

@end

@implementation MVVMCycleView

- (instancetype)initWithFrame:(CGRect)frame
                  andPointer1:(NSInteger *)pointer1
                  andPointer2:(NSInteger *)pointer2 {
    if (self = [super initWithFrame:frame]) {
        [self mvvm_observe:@"viewModel.state" with:^(typeof(self) self, NSNumber * value) {
            (*pointer1)++;
        }];
        [self mvvm_observe:@"viewModel.state" with:^(typeof(self) self, NSNumber * value) {
            (*pointer2)++;
        }];
    }
    return self;
}

@end

//

@interface MVVMTests : XCTestCase

@property (strong, nonatomic) MVVMCycleModelObject *viewModel;

@end

@implementation MVVMTests

- (void)setUp {
    [super setUp];
    self.viewModel = [[MVVMCycleModelObject alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testLongLivedViewModel {
    NSInteger observeCalledCount = 0;
    NSInteger observeCalledCount2 = 0;
    __weak MVVMCycleView *weakView = nil;

    @autoreleasepool {
        MVVMCycleView *view = [[MVVMCycleView alloc] initWithFrame:CGRectZero andPointer1:&observeCalledCount andPointer2:&observeCalledCount2];
        view.viewModel = self.viewModel;
        self.viewModel.state = 1;
        weakView = view;
    }

    XCTAssert(observeCalledCount == 3);
    XCTAssert(observeCalledCount2 == 3);
    XCTAssertNil(weakView);
}

- (void)testShortLivedViewModel {
    NSInteger observeCalledCount = 0;
    NSInteger observeCalledCount2 = 0;
    __weak MVVMCycleView *weakView = nil;

    @autoreleasepool {
        MVVMCycleView *view = [[MVVMCycleView alloc] initWithFrame:CGRectZero andPointer1:&observeCalledCount andPointer2:&observeCalledCount2];
        view.viewModel = [[MVVMCycleModelObject alloc] init];
        view.viewModel.state = 2;
        weakView = view;
    }

    XCTAssert(observeCalledCount == 3);
    XCTAssert(observeCalledCount2 == 3);
    XCTAssertNil(weakView);
}

- (void)testClassesExists {
    XCTAssertNotNil([MVVMObject class]);

    XCTAssertNotNil([MVVMViewController class]);

    XCTAssertNotNil([MVVMView class]);
    XCTAssertNotNil([MVVMButton class]);

    XCTAssertNotNil([MVVMTableView class]);
    XCTAssertNotNil([MVVMTableViewCell class]);

    XCTAssertNotNil([MVVMCollectionView class]);
    XCTAssertNotNil([MVVMCollectionViewCell class]);
    XCTAssertNotNil([MVVMCollectionReusableView class]);
}

@end
