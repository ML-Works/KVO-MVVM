//
//  MVVMView.h
//  KVO-MVVM
//
//  Created by Anton Bukov on 16.03.16.
//
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MVVMView : UIView

- (void)mvvm_observe:(NSString *)keyPath with:(void (^)(id self, id value))block;

@end

NS_ASSUME_NONNULL_END
