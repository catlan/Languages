//
//  LKContinueMode.h
//  LanguageKit
//
//  Created by Graham Lee on 21/02/2019.
//

#import <Foundation/Foundation.h>

#import "LKDebuggerMode.h"

/**
 * Continue Mode is the default mode of operation for the debugger.
 * It allows execution to continue unless a breakpoint is reached,
 * when it pauses the debugger.
 */
@interface LKContinueMode : NSObject <LKDebuggerMode>

@end
