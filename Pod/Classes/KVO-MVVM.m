//
//  KVO-MVVM.m
//  KVO-MVVM
//
//  Created by Andrew Podkovyrin on 16/03/16.
//
//

#import "KVO-MVVM.h"

#pragma mark - NSObject

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMObject
#define MVVM_TEMPLATE_SUPERCLASS NSObject
#include "MVVMClass.m.temp"

#pragma mark - UIViewController

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMViewController
#define MVVM_TEMPLATE_SUPERCLASS UIViewController
#include "MVVMClass.m.temp"

#pragma mark - UIView

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMView
#define MVVM_TEMPLATE_SUPERCLASS UIView
#include "MVVMClass.m.temp"

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMButton
#define MVVM_TEMPLATE_SUPERCLASS UIButton
#include "MVVMClass.m.temp"

#pragma mark - UITableView

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMTableView
#define MVVM_TEMPLATE_SUPERCLASS UITableView
#include "MVVMClass.m.temp"

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMTableViewCell
#define MVVM_TEMPLATE_SUPERCLASS UITableViewCell
#include "MVVMClass.m.temp"

#pragma mark - UICollectionView

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMCollectionView
#define MVVM_TEMPLATE_SUPERCLASS UICollectionView
#include "MVVMClass.m.temp"

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMCollectionViewCell
#define MVVM_TEMPLATE_SUPERCLASS UICollectionViewCell
#include "MVVMClass.m.temp"

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMCollectionReusableView
#define MVVM_TEMPLATE_SUPERCLASS UICollectionReusableView
#include "MVVMClass.m.temp"
