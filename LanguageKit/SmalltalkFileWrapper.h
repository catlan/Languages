//
//  SmalltalkFileWrapper.h
//
//  Created by Christopher Atlan on 05.09.17.
//  Copyright © 2017 Christopher Atlan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SmalltalkFileWrapper : NSFileWrapper

- (NSDictionary<NSString *, SmalltalkFileWrapper *> *)classFileWrappers;

- (NSDictionary<NSString *, SmalltalkFileWrapper *> *)extensionFileWrappers;

- (NSFileWrapper *)classDefinition;


@property (readonly) BOOL classMethod;
@property (readonly) NSString *selector;

- (NSDictionary<NSString *, NSFileWrapper *> *)classMethods;
- (NSDictionary<NSString *, NSFileWrapper *> *)instanceMethods;

- (NSArray<NSString *> *)methods;

- (NSString *)classMethodForSelector:(NSString *)selector;
- (void)setClassMethod:(NSString *)source forSelector:(NSString *)aSelector;

- (NSString *)instanceMethodForSelector:(NSString *)aSelector;
- (void)setInstanceMethod:(NSString *)source forSelector:(NSString *)aSelector;

- (NSString *)smalltalk;

@end
