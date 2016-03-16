//
//  KVO-MVVM.h
//  KVO-MVVM
//
//  Created by Anton Bukov on 16.03.16.
//
//

#import <UIKit/UIKit.h>

#pragma mark - UIViewController

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMViewController
#define MVVM_TEMPLATE_SUPERCLASS UIViewController
#include "MVVMClass.h"

#pragma mark - UIView

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMView
#define MVVM_TEMPLATE_SUPERCLASS UIView
#include "MVVMClass.h"

#pragma mark - UITableView

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMTableView
#define MVVM_TEMPLATE_SUPERCLASS UITableView
#include "MVVMClass.h"

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMTableViewCell
#define MVVM_TEMPLATE_SUPERCLASS UITableViewCell
#include "MVVMClass.h"

#pragma mark - UICollectionView

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMCollectionView
#define MVVM_TEMPLATE_SUPERCLASS UICollectionView
#include "MVVMClass.h"

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMCollectionViewCell
#define MVVM_TEMPLATE_SUPERCLASS UICollectionViewCell
#include "MVVMClass.h"

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
#define MVVM_TEMPLATE_CLASS MVVMCollectionReusableView
#define MVVM_TEMPLATE_SUPERCLASS UICollectionReusableView
#include "MVVMClass.h"

#undef MVVM_TEMPLATE_CLASS
#undef MVVM_TEMPLATE_SUPERCLASS
