//
//  LKLineBreakpointDescription.h
//  LanguageKit
//
//  Created by Graham Lee on 18/03/2019.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A description of a breakpoint by file name and line.
 * This is similar to the way an instruction debugger represents breakpoints,
 * e.g. gdb's main.c:42 or whatever.
 */
@interface LKLineBreakpointDescription : NSObject <NSSecureCoding>

/**
 * The name of the file in which the debugger will break.
 */
@property (readonly) NSString *file;
/**
 * The line on which the debugger will break.
 */
@property (readonly) NSUInteger line;

- (instancetype)initWithFile:(NSString *)file line:(NSUInteger)line;

@end

NS_ASSUME_NONNULL_END
