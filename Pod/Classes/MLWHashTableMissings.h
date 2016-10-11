//
//  MLWHachTableMissings.h
//  KVO-MVVM
//
//  Copyright (c) 2016 Machine Learning Works
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

void * _Nullable MLWMapGet(NSMapTable *table, const void * _Nullable key);
void MLWMapInsert(NSMapTable *table, const void * _Nullable key, const void * _Nullable value);
void MLWMapRemove(NSMapTable *table, const void * _Nullable key);

BOOL MLWHashGet(NSHashTable *table, const void * _Nullable pointer);
void MLWHashInsert(NSHashTable *table, const void * _Nullable pointer);
void MLWHashRemove(NSHashTable *table, const void * _Nullable pointer);

NS_ASSUME_NONNULL_END
