//
//  KVO-MVVM.m
//  KVO-MVVM
//
//  Created by Andrew Podkovyrin on 16/03/16.
//
//

#import "KVO-MVVM.h"

#pragma mark - UIViewController

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMViewController
#define MVVMBaseTemplate UIViewController
#include "MVVMClass.m.temp"

#pragma mark - UIView

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMView
#define MVVMBaseTemplate UIView
#include "MVVMClass.m.temp"

#pragma mark - UITableView

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMTableView
#define MVVMBaseTemplate UITableView
#include "MVVMClass.m.temp"

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMTableViewCell
#define MVVMBaseTemplate UITableViewCell
#include "MVVMClass.m.temp"

#pragma mark - UICollectionView

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMCollectionView
#define MVVMBaseTemplate UICollectionView
#include "MVVMClass.m.temp"

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMCollectionViewCell
#define MVVMBaseTemplate UICollectionViewCell
#include "MVVMClass.m.temp"

#undef MVVMTemplate
#undef MVVMBaseTemplate
#define MVVMTemplate MVVMCollectionReusableView
#define MVVMBaseTemplate UICollectionReusableView
#include "MVVMClass.m.temp"
