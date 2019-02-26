//
//  LKInterpreter.h
//  LanguageKit
//
//  Created by Graham Lee on 26/02/2019.
//

#import <Foundation/Foundation.h>

@class LKAST;
@class LKInterpreterContext;

/**
 * An interpreter is an object that executes LanguageKit syntax.
 * It maintains a reference to the AST being executed, and gives
 * a point for external observers such as debuggers to hook in to
 * the script's execution lifecycle.
 */
@interface LKInterpreter : NSObject

/**
 * Create an interpreter to execute the code represented by this AST.
 * The interpreter maintains a strong reference to the code, so that
 * if it is updated (e.g. by reloading a module) during execution, the
 * interpreter carries on executing the code it was given to completion.
 */
+ (instancetype)interpreterForCode:(LKAST *)root;

/**
 * Do it! Run the code in the interpreter.
 */
- (void)executeWithReceiver:(id)receiver
                  arguments:(const id*)arguments
                      count:(int)count
                  inContext:(LKInterpreterContext *)context;

/**
 * Find the return value of the last execution.
 */
- (id)returnValue;

@end
