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

- (void)startAgain;

@end

@implementation LKPauseMode
{
    dispatch_semaphore_t semaphore;
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
    if (self.service.shouldStop) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
}

- (void)startAgain
{
    if (self.service.shouldStop) {
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
@end
