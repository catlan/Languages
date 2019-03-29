//
//  LKPauseMode.m
//  LanguageKit
//
//  Created by Graham Lee on 21/02/2019.
//

#import "LKPauseMode.h"
#import "LKContinueMode.h"
#import "LKDebuggerService.h"
#import "LKStepIntoMode.h"
#import "LKStepOutMode.h"

@interface LKPauseMode ()

@property (atomic, readwrite, copy) NSArray<NSString *> *callStack;

- (void)startAgain;

@end

@implementation LKPauseMode
{
    dispatch_semaphore_t semaphore;
    LKDebuggerService *_pausedDebugger;
}

@synthesize service;

- (instancetype)init {
    self = [super init];
    if (self) {
        semaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)onTracepoint:(LKAST *)aNode
{
    [[NSException exceptionWithName:@"LKDebuggerTracedWhilePausedException"
                             reason:@"A paused debugger should not encounter a tracepoint"
                           userInfo:nil] raise];
}

- (void)pause
{
    [[NSException exceptionWithName:@"LKDebuggerRecursivePauseException"
                             reason:@"A paused debugger can't pause"
                           userInfo:nil] raise];
}

- (void)resume
{
    self.service.mode = [LKContinueMode new];
    [self startAgain];
}

- (void)waitHere
{
    // save the callstack here, it won't change before someone asks for it
    self.callStack = [NSThread callStackSymbols];
    if (self.service.shouldStop) {
        /*
         * Temporarily keep a strong reference to my debugger until we resume.
         * This avoids a circular problem where if you set a new mode before
         * resuming, you have set this mode's service to nil so it can't resume
         * the debugger, but if you resume before updating the mode, the debugger
         * would continue executing its script before getting any more instructions.
         */
        _pausedDebugger = self.service;
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
}

- (void)startAgain
{
    if (_pausedDebugger.shouldStop) {
        _pausedDebugger = nil;
        dispatch_semaphore_signal(semaphore);
    }
}

- (void)stepInto
{
    self.service.mode = [LKStepIntoMode new];
    [self startAgain];
}

- (void)stepOut
{
    self.service.mode = [LKStepOutMode new];
    [self startAgain];
}

- (NSArray<NSString *> *)stacktrace
{
    /*
     * rely on the callstack having been captured when we paused.
     * there is a very small potential for a race, if you manage to ask
     * for the stacktrace while the mode is still pausing. You'll get nil,
     * and should ask again.
     */
    return self.callStack;
}

- (LKDebuggerStatus)status
{
    return DebuggerStatusWaitingAtBreakpoint;
}

@end
