//
//  LKPauseMode.h
//  LanguageKit
//
//  Created by Graham Lee on 21/02/2019.
//

#import <Foundation/Foundation.h>

#import "LKDebuggerMode.h"

@interface LKPauseMode : NSObject <LKDebuggerMode>

/**
 * If the debugger should stop, then wait until a continue or step command.
 */
- (void)waitHere;

@end
