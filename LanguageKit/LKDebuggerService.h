//
//  LKDebuggerService.h
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>

@protocol LKDebuggerMode;

/**
 * A debugger service controls the debugging operation, and shows the
 * state of the script being debugged to the user. It delegates commands
 * to a mode object that chooses how to respond to different events.
 */
@interface LKDebuggerService : NSObject

/**
 * Called by the interpreter when it evaluates an AST node.
 */
- (void)onTracepoint: (LKAST *)aNode;
/**
 * The interpreter's current location.
 */
- (LKAST *)currentNode;
/**
 * Set the debugger's current mode.
 */
- (void)setMode: (id<LKDebuggerMode>)aMode;

@end
