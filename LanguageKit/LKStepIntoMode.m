//
//  LKStepIntoMode.m
//  LanguageKit
//
//  Created by Graham Lee on 21/02/2019.
//

#import "LKStepIntoMode.h"
#import "LKDebuggerService.h"
#import "LKPauseMode.h"

@implementation LKStepIntoMode

@synthesize service;

- (void)onTracepoint:(LKAST *)aNode {
    [self.service pause];
}

- (void)pause {
    LKPauseMode *nextMode = [LKPauseMode new];
    self.service.mode = nextMode;
    [nextMode waitHere];
}

- (void)resume {
    [[NSException exceptionWithName:@"LKDebuggerRecursiveContinueException"
                             reason:@"A running debugger cannot be resumed"
                           userInfo:nil] raise];
}

- (void)stepInto {
    [[NSException exceptionWithName:@"LKDebuggerRecursiveContinueException"
                             reason:@"A running debugger cannot be resumed"
                           userInfo:nil] raise];
}

@end
