#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "KVO-MVVM.h"
#import "MLWHashTableMissings.h"

FOUNDATION_EXPORT double KVO_MVVMVersionNumber;
FOUNDATION_EXPORT const unsigned char KVO_MVVMVersionString[];

