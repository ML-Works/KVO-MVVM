//
//  SimpleKVOTests.m
//  KVO-MVVM
//
//  Created by Anton Bukov on 30.08.16.
//  Copyright © 2016 Anton Bukov. All rights reserved.
//

#import <XCTest/XCTest.h>

//

@interface SimpleKVOModel : NSObject

@property (strong, nonatomic) NSNumber *number;

@end

@implementation SimpleKVOModel

@end

@interface SimpleKVO : NSObject

@property (strong, nonatomic) SimpleKVOModel *viewModel;
@property (assign, nonatomic) BOOL observerWasCalled;

@end

@implementation SimpleKVO

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

@interface SimpleKVOTests : XCTestCase

@end

@implementation SimpleKVOTests

- (void)testSimpleKVONotBroken {
    SimpleKVO *object = [SimpleKVO new];
    object.viewModel = [SimpleKVOModel new];
    object.viewModel.number = @1;
    
    XCTAssertTrue(object.observerWasCalled);
}

@end
