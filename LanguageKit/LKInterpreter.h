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
 * It maintains a reference to the AST being executed while it is executed,
 * and gives a point for external observers such as debuggers to hook in to
 * the script's execution lifecycle.
 */
@interface LKInterpreter : NSObject

/**
 * Get an interpreter for running some code.
 * @note Never create your own interpreter; always use this method.
 */
+ (instancetype)interpreter;

/**
 * Do it! Run the code in the interpreter.
 */
- (void)executeCode:(LKAST *)rootNode
       withReceiver:(id)receiver
          arguments:(const id*)arguments
              count:(int)count;

/**
 * Find the return value of the last execution.
 */
- (id)returnValue;

/**
 * Push a new context to the top of this interpreter's context stack.
 */
- (void)pushContext: (LKInterpreterContext *)aContext;
/**
 * Pop the topmost interpreter context from this interpreter's context stack.
 */
- (void)popContext;
/**
 * The interpreter context at the top of this interpreter's context stack.
 */
- (LKInterpreterContext *)topContext;

@end
