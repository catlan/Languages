//
//  LKDebuggerMode.h
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>
#import <LanguageKit/LKDebuggerStatus.h>

@class LKAST;
@class LKDebuggerService;

/**
 * A debugger mode is an object that can tell the debugger what to do
 * when particular debugging events occur. In effect, it is the Strategy
 * pattern for debugging.
 */
@protocol LKDebuggerMode <NSObject>

/**
 * The debugger service associated with this mode object.
 */
@property (nonatomic, weak) LKDebuggerService *service;
/**
 * Received when the debugger service encounters a new node. A mode
 * object may need the debugger to switch mode, check whether the node
 * matches the definition of a breakpoint, or update some UI when a
 * tracepoint is reached.
 */
- (void)onTracepoint: (LKAST *)aNode;
/**
 * Pause the debugger.
 * @throws If the debugger is not in a state where it can pause (e.g. it is already paused).
 */
- (void)pause;
/**
 * Resume execution.
 * @throws If the debugger cannot resume (e.g. it is already running).
 */
- (void)resume;
/**
 * Step into the next AST node.
 * @throws If the debugger cannot step (e.g. it is already running).
 */
- (void)stepInto;
/**
 * Step out of the current block, function or method.
 * @throws If the debugger cannot step (e.g. it is already running).
 */
- (void)stepOut;
/**
 * Get the stack trace of the script being debugged.
 * @throws If the stack trace cannot be retried (e.g. the debugger is running).
 */
- (NSArray <NSString *>*)stacktrace;
/**
 * Return the current status of the debugger.
 */
- (LKDebuggerStatus)status;

@end
