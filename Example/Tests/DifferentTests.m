//
//  DifferentTests.m
//  KVO-MVVM
//
//  Created by Anton Bukov on 10.10.16.
//  Copyright © 2016 Anton Bukov. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface DoubleObserveClass : NSObject

@property (strong, nonatomic) NSString *stringValue;

@end

@implementation DoubleObserveClass

- (instancetype)init {
    self = [super init];
    if (self) {
        [self addObserver:self forKeyPath:@"stringValue" options:NSKeyValueObservingOptionNew context:(void *)0x1];
        [self addObserver:self forKeyPath:@"stringValue" options:NSKeyValueObservingOptionNew context:(void *)0x2];
    }
    return self;
}

@end

//

@interface DifferentTests : XCTestCase

@end

@implementation DifferentTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    @autoreleasepool {
        [DoubleObserveClass new];
    }
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
