//
//  LKDebuggerService.h
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>

@protocol LKDebuggerMode;
@class LKInterpreterContext;
@class LKVariableDescription;

/**
 * A debugger service controls the debugging operation, and shows the
 * state of the script being debugged to the user. It delegates commands
 * to a mode object that chooses how to respond to different events.
 */
@interface LKDebuggerService : NSObject

/**
 * The mode is like a State or Strategy for the debugger, and chooses
 * what to do when important events occur.
 */
@property (nonatomic, strong) id <LKDebuggerMode> mode;

/**
 * Whether the debugger should really pause when requested. You can turn
 * this off to basically globally disable breakpoints, whether to effect the
 * equivalent of "detaching" the debugger or to write a unit test without a
 * load of multi-threaded boilerplate (just, y'know, for instance).
 */
@property (nonatomic, assign) BOOL shouldStop;

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
 * Run a script using the current debugger mode to control execution.
 */
- (void)debugScript: (LKAST *)rootNode;
/**
 * Get the values of variables defined at the current tracepoint.
 * @return An unordered collection of variable descriptions.
 */
- (NSSet<LKVariableDescription *> *)allVariables;
/**
 * Add a breakpoint to the debugger. The debugger will pause script execution
 * when it encounters a node that matches a breakpoint.
 */
- (void)addBreakpoint: (LKAST *)breakAtNode;
/**
 * Discover whether the debugger should break when it encounters this node.
 */
- (BOOL)hasBreakpointAt: (LKAST *)aNode;
/**
 * Stop the debugger.
 */
- (void)pause;
/**
 * Resume execution.
 */
- (void)resume;
@end
