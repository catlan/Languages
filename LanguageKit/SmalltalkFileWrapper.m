//
//  SmalltalkFileWrapper.m
//
//  Created by Christopher Atlan on 05.09.17.
//  Copyright © 2017 Christopher Atlan. All rights reserved.
//

#import "SmalltalkFileWrapper.h"

@interface SmalltalkFileWrapper ()
@property (readwrite) BOOL classMethod;
@end

@implementation SmalltalkFileWrapper

+ (NSString *)filenameForSelector:(NSString *)selector
{
    NSString *filename = [selector stringByReplacingOccurrencesOfString:@":" withString:@"_"];
    filename = [filename stringByAppendingPathExtension:@"st"];
    return filename;
}

+ (NSString *)selectorForFilename:(NSString *)filename
{
    NSString *selector = [filename stringByDeletingPathExtension];
    selector = [selector stringByReplacingOccurrencesOfString:@"_" withString:@":"];
    return selector;
}

- (NSDictionary<NSString *, NSFileWrapper *> *)classFileWrappers
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (NSString *filename in [self fileWrappers])
    {
        if ([filename hasSuffix:@"class"])
        {
            [dictionary setObject:[[self fileWrappers] objectForKey:filename] forKey:filename];
        }
    }
    return [dictionary copy];
}

- (NSDictionary<NSString *, SmalltalkFileWrapper *> *)extensionFileWrappers
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (NSString *filename in [self fileWrappers])
    {
        if ([filename hasSuffix:@"extension"])
        {
            [dictionary setObject:[[self fileWrappers] objectForKey:filename] forKey:filename];
        }
    }
    return [dictionary copy];
}

- (NSFileWrapper *)classDefinition
{
    NSFileWrapper *classDefinition = [[self fileWrappers] objectForKey:@"classDefinition.st"];
    if (!classDefinition)
    {
        classDefinition = [[[self class] alloc] init];
        [classDefinition setFilename:@"classDefinition.st"];
        [classDefinition setPreferredFilename:@"classDefinition.st"];
        [self addFileWrapper:classDefinition];
    }
    return classDefinition;
}


- (NSFileWrapper *)classMethodsFileWrapper
{
    NSFileWrapper *fileWrapper = [[self fileWrappers] objectForKey:@"class"];
    if (!fileWrapper)
    {
        fileWrapper = [[[self class] alloc] initDirectoryWithFileWrappers:@{}];
        [fileWrapper setFilename:@"class"];
        [fileWrapper setPreferredFilename:@"class"];
        [self addFileWrapper:fileWrapper];
    }
    return fileWrapper ;
}

- (NSDictionary<NSString *, NSFileWrapper *> *)classMethods
{
    NSDictionary *classMethods = [[self classMethodsFileWrapper] fileWrappers];
    NSMutableDictionary *filteredClassMethods = [classMethods mutableCopy];
    for (NSString *filename in classMethods) {
        if ([filename hasPrefix:@"."])
        {
            [filteredClassMethods removeObjectForKey:filename];
        }
    }
    for (SmalltalkFileWrapper *fileWrapper in [filteredClassMethods objectEnumerator]) {
        [fileWrapper setClassMethod:YES];
    }
    return [filteredClassMethods copy];
}

- (NSFileWrapper *)instanceMethodsFileWrapper
{
    NSFileWrapper *fileWrapper = [[self fileWrappers] objectForKey:@"instance"];
    if (!fileWrapper)
    {
        fileWrapper = [[[self class] alloc] initDirectoryWithFileWrappers:@{}];
        [fileWrapper setFilename:@"instance"];
        [fileWrapper setPreferredFilename:@"instance"];
        [self addFileWrapper:fileWrapper];
    }
    return fileWrapper;
}

- (NSDictionary<NSString *, NSFileWrapper *> *)instanceMethods
{
    NSDictionary *instanceMethods = [[self instanceMethodsFileWrapper] fileWrappers];
    NSMutableDictionary *filteredInstanceMethods = [instanceMethods mutableCopy];
    for (NSString *filename in instanceMethods) {
        if ([filename hasPrefix:@"."])
        {
            [filteredInstanceMethods removeObjectForKey:filename];
        }
    }
    return [filteredInstanceMethods copy];
}

- (NSFileWrapper *)classMethodFileWrapperForSelector:(NSString *)selector
{
    NSString *filename = [[self class] filenameForSelector:selector];
    return [[self classMethods] objectForKey:filename];
}

- (NSString *)classMethodForSelector:(NSString *)selector
{
    NSFileWrapper *fileWrapper = [self classMethodFileWrapperForSelector:selector];
    return [[NSString alloc] initWithData:[fileWrapper regularFileContents] encoding:NSUTF8StringEncoding];
}

- (NSFileWrapper *)instanceMethodFileWrapperForSelector:(NSString *)selector
{
    NSString *filename = [[self class] filenameForSelector:selector];
    return [[self instanceMethods] objectForKey:filename];
}

- (void)setClassMethod:(NSString *)source forSelector:(NSString *)aSelector
{
    NSFileWrapper *classMethodsFileWrapper = [self classMethodsFileWrapper];
    NSString *filename = [[self class] filenameForSelector:aSelector];
    NSFileWrapper *fileWrapper = [[classMethodsFileWrapper fileWrappers] objectForKey:filename];
    [classMethodsFileWrapper removeFileWrapper:fileWrapper];
    if (source)
    {
        NSData *data = [source dataUsingEncoding:NSUTF8StringEncoding];
        [classMethodsFileWrapper addRegularFileWithContents:data preferredFilename:filename];
    }
}

- (NSString *)instanceMethodForSelector:(NSString *)selector
{
    NSFileWrapper *fileWrapper = [self instanceMethodFileWrapperForSelector:selector];
    return [[NSString alloc] initWithData:[fileWrapper regularFileContents] encoding:NSUTF8StringEncoding];
}

- (void)setInstanceMethod:(NSString *)source forSelector:(NSString *)aSelector
{
    NSFileWrapper *instanceMethodsFileWrapper = [self instanceMethodsFileWrapper];
    NSString *filename = [[self class] filenameForSelector:aSelector];
    NSFileWrapper *fileWrapper = [[instanceMethodsFileWrapper fileWrappers] objectForKey:filename];
    [instanceMethodsFileWrapper removeFileWrapper:fileWrapper];
    if (source)
    {
        NSData *data = [source dataUsingEncoding:NSUTF8StringEncoding];
        [instanceMethodsFileWrapper addRegularFileWithContents:data preferredFilename:filename];
    }
}

- (NSArray<NSString *> *)methods
{
    NSMutableArray *methods = [NSMutableArray array];
    [methods addObjectsFromArray:[[[self classMethods] objectEnumerator] allObjects]];
    [methods addObjectsFromArray:[[[self instanceMethods] objectEnumerator] allObjects]];

    return [methods copy];
}

- (NSString *)displayName
{
    NSString *filename = [self filename] ?: [self preferredFilename];
    NSString *selector = [[self class] selectorForFilename:filename];
    if ([self classMethod])
    {
        return [@"+ " stringByAppendingString:selector];
    }
    return selector;
}

- (NSString *)selector
{
    NSString *filename = [self filename] ?: [self preferredFilename];
    return [[self class] selectorForFilename:filename];
}

- (NSString *)smalltalk
{
    NSMutableString *source = [NSMutableString string];
    NSString *classDefinition = [[NSString alloc] initWithData:[[self classDefinition] regularFileContents] encoding:NSUTF8StringEncoding];
    if (!classDefinition)
        return source;
    
    [source appendString:classDefinition];
    [source appendString:@"\n"];
    
    for (NSFileWrapper *fileWrapper in [[self classMethods] objectEnumerator])
    {
        if (![fileWrapper isRegularFile])
            continue;
        NSString *method = [[NSString alloc] initWithData:[fileWrapper regularFileContents] encoding:NSUTF8StringEncoding];
        if (method)
        {
            [source appendString:method];
            [source appendString:@"\n"];
        }
    }
    
    for (NSFileWrapper *fileWrapper in [[self instanceMethods] objectEnumerator])
    {
        if (![fileWrapper isRegularFile])
            continue;
        NSString *method = [[NSString alloc] initWithData:[fileWrapper regularFileContents] encoding:NSUTF8StringEncoding];
        if (method)
        {
            [source appendString:method];
            [source appendString:@"\n"];
        }
    }
    
    [source appendString:@"]\n"];
    [source appendString:@"\n"];
    
    return source;
}

@end
