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
@property (strong, nonatomic) NSArray<NSNumber *> *properties;
@property (readonly, strong, nonatomic) NSMutableArray<NSNumber *> *mutableProperties;

@end

@implementation MVVMCycleModelObject

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

@interface MVVMCycleView : MVVMView

@property (strong, nonatomic) MVVMCycleModelObject *viewModel;

@end

@implementation MVVMCycleView

- (instancetype)initWithFrame:(CGRect)frame
                      options:(NSKeyValueObservingOptions)options
          viewModelStateBlock:(void (^)(MVVMCycleView *self, NSNumber *value))viewModelStateBlock
     viewModelPropertiesBlock:(void (^)(MVVMCycleView *self, NSNumber *value, NSKeyValueChange change, NSIndexSet *indexes))viewModelPropertiesBlock {
    if (self = [super initWithFrame:frame]) {
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

- (void)testClassesExists {
    XCTAssertNotNil([MVVMObject class]);

    XCTAssertNotNil([MVVMViewController class]);

    XCTAssertNotNil([MVVMView class]);
    XCTAssertNotNil([MVVMControl class]);
    XCTAssertNotNil([MVVMButton class]);

    XCTAssertNotNil([MVVMTableView class]);
    XCTAssertNotNil([MVVMTableViewCell class]);

    XCTAssertNotNil([MVVMCollectionView class]);
    XCTAssertNotNil([MVVMCollectionViewCell class]);
    XCTAssertNotNil([MVVMCollectionReusableView class]);
}

- (void)testShortLivedViewModel {
    __block NSInteger observeCalledCount = 0;
    __block NSInteger observeCalledCount2 = 0;
    __weak MVVMCycleView *weakView = nil;

    @autoreleasepool {
        MVVMCycleView *view = [[MVVMCycleView alloc] initWithFrame:CGRectZero options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) viewModelStateBlock:^(MVVMCycleView *self, NSNumber *value) {
            observeCalledCount++;
        }
            viewModelPropertiesBlock:^(MVVMCycleView *self, NSNumber *value, NSKeyValueChange change, NSIndexSet *indexes) {
                observeCalledCount2++;
            }];
        XCTAssertEqual(observeCalledCount, 1);
        XCTAssertEqual(observeCalledCount2, 1);
        
        view.viewModel = [[MVVMCycleModelObject alloc] init];
        XCTAssertEqual(observeCalledCount, 2);
        XCTAssertEqual(observeCalledCount2, 2);
        
        view.viewModel.state = 2;
        XCTAssertEqual(observeCalledCount, 3);
        XCTAssertEqual(observeCalledCount2, 2);
        
        weakView = view;
    }

    XCTAssertNil(weakView);
}

- (void)testWithoutInitialCall {
    __block NSInteger observeCalledCount = 0;
    __block NSInteger observeCalledCount2 = 0;

    MVVMCycleView *view = [[MVVMCycleView alloc] initWithFrame:CGRectZero options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) viewModelStateBlock:^(MVVMCycleView *self, NSNumber *value) {
        observeCalledCount++;
    }
        viewModelPropertiesBlock:^(MVVMCycleView *self, NSNumber *value, NSKeyValueChange change, NSIndexSet *indexes) {
            observeCalledCount2++;
        }];
    XCTAssertEqual(observeCalledCount, 0);
    XCTAssertEqual(observeCalledCount2, 0);
    
    view.viewModel = [[MVVMCycleModelObject alloc] init];
    XCTAssertEqual(observeCalledCount, 1);
    XCTAssertEqual(observeCalledCount2, 1);
    
    view.viewModel.state = 2;
    XCTAssertEqual(observeCalledCount, 2);
    XCTAssertEqual(observeCalledCount2, 1);
}

- (void)testObserveCollection {
    __block NSKeyValueChange lastChange = 0;
    __block NSIndexSet *lastIndexes = nil;

    MVVMCycleView *view = [[MVVMCycleView alloc] initWithFrame:CGRectZero options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) viewModelStateBlock:nil viewModelPropertiesBlock:^(MVVMCycleView *self, NSNumber *value, NSKeyValueChange change, NSIndexSet *indexes) {
        lastChange = change;
        lastIndexes = indexes;
    }];
    XCTAssertEqual(lastChange, 0);
    XCTAssertEqualObjects(lastIndexes, nil);

    view.viewModel = [[MVVMCycleModelObject alloc] init];
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

@end
