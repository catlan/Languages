//
//  LKDebuggerService.h
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>

@protocol LKDebuggerMode;
@class LKVariableDescription;

/**
 * A debugger service controls the debugging operation, and shows the
 * state of the script being debugged to the user. It delegates commands
 * to a mode object that chooses how to respond to different events.
 */
@interface LKDebuggerService : NSObject

/**
 * Called by the interpreter when it evaluates an AST node.
 * @param aNode the AST node that was encountered.
 * @param context the interpreter context in which the node was evaluated.
 */
- (void)onTracepoint: (LKAST *)aNode inContext: (LKInterpreterContext *)context;
/**
 * The interpreter's current location.
 */
- (LKAST *)currentNode;
/**
 * Set the debugger's current mode.
 */
- (void)setMode: (id<LKDebuggerMode>)aMode;
/**
 * Run a script using the current debugger mode to control execution.
 */
- (void)debugScript: (LKAST *)rootNode;
/**
 * Get the values of variables defined at the current tracepoint.
 * @return An unordered collection of variable descriptions.
 */
- (NSSet<LKVariableDescription *> *)allVariables;
@end
