//
//  SteppingModeTests.m
//  LanguageKitTests
//
//  Created by Graham Lee on 21/02/2019.
//

#import <XCTest/XCTest.h>
#import "LKComment.h"
#import "LKDebuggerService.h"
#import "LKPauseMode.h"
#import "LKStepIntoMode.h"

@interface SteppingModeTests : XCTestCase

@end

@implementation SteppingModeTests
{
    LKDebuggerService *_debugger;
    LKStepIntoMode *_mode;
}

- (void)setUp {
    _debugger = [LKDebuggerService new];
    _debugger.shouldStop = NO;
    _mode = [LKStepIntoMode new];
    _debugger.mode = _mode;
}

- (void)tearDown {
    _debugger = nil;
    _mode = nil;
}

- (void)testTracingANodeInStepIntoModePausesTheDebugger {
    LKComment *aNode = [LKComment commentWithString:@"a comment"];
    [_mode onTracepoint:aNode];
    XCTAssertEqualObjects([_debugger.mode class], [LKPauseMode class], @"Debugger has paused");
}

@end
