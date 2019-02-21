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
#import "LKReturn.h"
#import "LKStepIntoMode.h"
#import "LKStepOutMode.h"

@interface SteppingModeTests : XCTestCase

@end

@implementation SteppingModeTests
{
    LKDebuggerService *_debugger;
    LKStepOutMode *_mode;
    LKComment *_comment;
}

- (void)setUp {
    _debugger = [LKDebuggerService new];
    _debugger.shouldStop = NO;
    _mode = [LKStepOutMode new];
    _debugger.mode = _mode;
    _comment = [LKComment commentWithString:@"a comment"];
}

- (void)tearDown {
    _debugger = nil;
    _mode = nil;
    _comment = nil;
}

- (void)testTracingANodeInStepIntoModePausesTheDebugger {
    LKStepIntoMode *stepIntoMode = [LKStepIntoMode new];
    _debugger.mode = stepIntoMode;
    [stepIntoMode onTracepoint:_comment];
    XCTAssertEqualObjects([_debugger.mode class], [LKPauseMode class], @"Debugger has paused");
}

- (void)testTracingACommentInStepOutModeDoesNotPauseTheDebugger {
    [_mode onTracepoint:_comment];
    XCTAssertEqualObjects(_debugger.mode, _mode, @"Debugger did not switch modes");
}

- (void)testTracingABreakpointInStepOutModePausesTheDebugger {
    [_debugger addBreakpoint:_comment];
    [_mode onTracepoint:_comment];
    XCTAssertEqualObjects([_debugger.mode class], [LKPauseMode class], @"Debugger has paused");
    [_debugger removeBreakpoint:_comment];
}

- (void)testTracingAReturnNodeInStepOutModePausesTheDebugger {
    LKReturn *returnValue = [LKReturn returnWithExpr:nil];
    [_mode onTracepoint:returnValue];
    XCTAssertEqualObjects([_debugger.mode class], [LKPauseMode class], @"Debugger has paused");
}

@end
