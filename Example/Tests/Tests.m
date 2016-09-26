//
//  KVO-MVVMTests.m
//  KVO-MVVMTests
//
//  Created by Anton Bukov on 03/16/2016.
//  Copyright (c) 2016 Anton Bukov. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <KVO-MVVM/KVO-MVVM.h>

//

@interface TestViewModel : NSObject

@property (strong, nonatomic) NSString *state;
@property (strong, nonatomic) NSArray<NSNumber *> *properties;
@property (readonly, strong, nonatomic) NSMutableArray<NSNumber *> *mutableProperties;

@end

@implementation TestViewModel

- (NSArray<NSNumber *> *)properties {
    if (_properties == nil) {
        _properties = [NSArray array];
    }
    return _properties;
}

- (NSMutableArray<NSNumber *> *)mutableProperties {
    return [self mutableArrayValueForKey:NSStringFromSelector(@selector(properties))];
}

@end

//

@interface TestView : NSObject

@property (strong, nonatomic) TestViewModel *viewModel;

@end

@implementation TestView

- (instancetype)initWithOptions:(NSKeyValueObservingOptions)options
            viewModelStateBlock:(void (^)(TestView *self, NSNumber *value))viewModelStateBlock
       viewModelPropertiesBlock:(void (^)(TestView *self, NSNumber *value, NSKeyValueChange change, NSIndexSet *indexes))viewModelPropertiesBlock {
    if (self = [super init]) {
        if (viewModelStateBlock) {
            [self mvvm_observe:@"viewModel.state" options:options with:^(typeof(self) self, NSNumber * value) {
                viewModelStateBlock(self, value);
            }];
        }
        if (viewModelPropertiesBlock) {
            [self mvvm_observeCollection:@"viewModel.properties" options:options with:^(typeof(self) self, id value, NSKeyValueChange change, NSIndexSet * indexes) {
                viewModelPropertiesBlock(self, value, change, indexes);
            }];
        }
    }
    return self;
}

@end

//

@interface MVVMTests : XCTestCase

@property (strong, nonatomic) TestViewModel *viewModel;

@end

@implementation MVVMTests

- (void)setUp {
    [super setUp];
    self.viewModel = [[TestViewModel alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testShortLivedViewModel {
    @autoreleasepool {
        __block NSInteger observeCalledCount = 0;
        __block NSInteger observeCalledCount2 = 0;
        __weak TestView *weakView = nil;

        @autoreleasepool {
            TestView *view = [[TestView alloc] initWithOptions:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) viewModelStateBlock:^(TestView *self, NSNumber *value) {
                observeCalledCount++;
            }
                viewModelPropertiesBlock:^(TestView *self, NSNumber *value, NSKeyValueChange change, NSIndexSet *indexes) {
                    observeCalledCount2++;
                }];
            XCTAssertEqual(observeCalledCount, 1);
            XCTAssertEqual(observeCalledCount2, 1);

            view.viewModel = [[TestViewModel alloc] init];
            XCTAssertEqual(observeCalledCount, 1);
            XCTAssertEqual(observeCalledCount2, 2);

            view.viewModel.state = @"2";
            XCTAssertEqual(observeCalledCount, 2);
            XCTAssertEqual(observeCalledCount2, 2);

            weakView = view;
        }

        XCTAssertNil(weakView);
    }
}

- (void)testWithoutInitialCall {
    @autoreleasepool {
        __block NSInteger observeCalledCount = 0;
        __block NSInteger observeCalledCount2 = 0;

        TestView *view = [[TestView alloc] initWithOptions:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) viewModelStateBlock:^(TestView *self, NSNumber *value) {
            observeCalledCount++;
        }
            viewModelPropertiesBlock:^(TestView *self, NSNumber *value, NSKeyValueChange change, NSIndexSet *indexes) {
                observeCalledCount2++;
            }];
        XCTAssertEqual(observeCalledCount, 0);
        XCTAssertEqual(observeCalledCount2, 0);

        view.viewModel = [[TestViewModel alloc] init];
        XCTAssertEqual(observeCalledCount, 0);
        XCTAssertEqual(observeCalledCount2, 1);

        view.viewModel.state = @"2";
        XCTAssertEqual(observeCalledCount, 1);
        XCTAssertEqual(observeCalledCount2, 1);
    }
}

- (void)testObserveCollection {
    @autoreleasepool {
        __block NSKeyValueChange lastChange = 0;
        __block NSIndexSet *lastIndexes = nil;

        TestView *view = [[TestView alloc] initWithOptions:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) viewModelStateBlock:nil viewModelPropertiesBlock:^(TestView *self, NSNumber *value, NSKeyValueChange change, NSIndexSet *indexes) {
            lastChange = change;
            lastIndexes = indexes;
        }];
        XCTAssertEqual(lastChange, 0);
        XCTAssertEqualObjects(lastIndexes, nil);

        view.viewModel = [[TestViewModel alloc] init];
        XCTAssertEqual(lastChange, NSKeyValueChangeSetting);
        XCTAssertEqualObjects(lastIndexes, nil);

        [view.viewModel.mutableProperties addObject:@1];
        XCTAssertEqual(lastChange, NSKeyValueChangeInsertion);
        XCTAssertEqualObjects(lastIndexes, [NSIndexSet indexSetWithIndex:0]);

        [view.viewModel.mutableProperties addObject:@2];
        XCTAssertEqual(lastChange, NSKeyValueChangeInsertion);
        XCTAssertEqualObjects(lastIndexes, [NSIndexSet indexSetWithIndex:1]);

        [view.viewModel.mutableProperties addObject:@3];
        XCTAssertEqual(lastChange, NSKeyValueChangeInsertion);
        XCTAssertEqualObjects(lastIndexes, [NSIndexSet indexSetWithIndex:2]);

        [view.viewModel.mutableProperties removeObjectAtIndex:1];
        XCTAssertEqual(lastChange, NSKeyValueChangeRemoval);
        XCTAssertEqualObjects(lastIndexes, [NSIndexSet indexSetWithIndex:1]);

        [view.viewModel.mutableProperties replaceObjectAtIndex:0 withObject:@4];
        XCTAssertEqual(lastChange, NSKeyValueChangeReplacement);
        XCTAssertEqualObjects(lastIndexes, [NSIndexSet indexSetWithIndex:0]);
    }
}

@end
