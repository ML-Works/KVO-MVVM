//
//  KVO-MVVM.h
//  KVO-MVVM
//
//  Created by Anton Bukov on 16.03.16.
//
//

#import <UIKit/UIKit.h>

#pragma mark - UIViewController

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMViewController
#define MVVMBaseTemplate UIViewController
#include "MVVMClass.h"

#pragma mark - UIView

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMView
#define MVVMBaseTemplate UIView
#include "MVVMClass.h"

#pragma mark - UITableView

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMTableView
#define MVVMBaseTemplate UITableView
#include "MVVMClass.h"

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMTableViewCell
#define MVVMBaseTemplate UITableViewCell
#include "MVVMClass.h"

#pragma mark - UICollectionView

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMCollectionView
#define MVVMBaseTemplate UICollectionView
#include "MVVMClass.h"

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMCollectionViewCell
#define MVVMBaseTemplate UICollectionViewCell
#include "MVVMClass.h"

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMCollectionReusableView
#define MVVMBaseTemplate UICollectionReusableView
#include "MVVMClass.h"

#undef MVVMTemplate
#undef MVVMBaseTemplate
