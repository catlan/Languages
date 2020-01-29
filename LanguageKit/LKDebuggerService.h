//
//  LKDebuggerService.h
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>

@protocol LKDebuggerMode;
@class LKAST;
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
 */
- (void)onTracepoint: (LKAST *)aNode;
/**
 * The interpreter's current location.
 */
- (LKAST *)currentNode;
/**
 * Scripts run after this debugger is activated can be debugged by it.
 */
- (void)activate;
/**
 * This debugger should no longer be active, and scripts should not be debugged.
 */
- (void)deactivate;
/**
 * Get the values of variables defined at the current tracepoint.
 * @return An unordered collection of variable descriptions.
 */
- (NSSet<LKVariableDescription *> *)allVariables;
/**
 * Get the call stack at the current location.
 */
- (NSArray<NSString *> *)stacktrace;
/**
 * Add a breakpoint to the debugger. The debugger will pause script execution
 * when it encounters a node that matches a breakpoint.
 */
- (void)addBreakpoint: (LKAST *)breakAtNode;
/**
 * Remove a breakpoint from the debugger. The debugger will no longer pause
 * script execution when it encounters this node.
 */
- (void)removeBreakpoint: (LKAST *)breakpoint;
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
/**
 * Single-step the debugger.
 */
- (void)stepInto;
/**
 * Step out of the current function, method or block.
 */
- (void)stepOut;
@end
