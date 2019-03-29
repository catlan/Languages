//
//  LKDebuggerStatus.h
//  LanguageKit
//
//  Created by Graham Lee on 19/03/2019.
//

#ifndef LKDebuggerStatus_h
#define LKDebuggerStatus_h

typedef enum : NSUInteger {
    DebuggerStatusDisconnected,
    DebuggerStatusNotRunning,
    DebuggerStatusRunning,
    DebuggerStatusWaitingAtBreakpoint,
    DebuggerStatusUnknown = NSNotFound,
} LKDebuggerStatus;

#endif /* LKDebuggerStatus_h */
