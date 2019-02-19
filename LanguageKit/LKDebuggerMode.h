//
//  LKDebuggerMode.h
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>

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

@end
