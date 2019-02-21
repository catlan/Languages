//
//  ContinueModeTests.m
//  LanguageKitTests
//
//  Created by Graham Lee on 21/02/2019.
//

#import <XCTest/XCTest.h>
#import "LKComment.h"
#import "LKContinueMode.h"
#import "LKDebuggerService.h"
#import "LKPauseMode.h"

@interface ContinueModeTests : XCTestCase

@end

@implementation ContinueModeTests
{
    LKDebuggerService *_debugger;
    LKContinueMode *_mode;
    LKAST *_node;
}

- (void)setUp {
    _debugger = [LKDebuggerService new];
    _debugger.shouldStop = NO;
    _mode = _debugger.mode;
    _node = [LKComment commentWithString:@"// TODO: fix me"];
}

- (void)tearDown {
    _debugger = nil;
    _mode = nil;
}

- (void)testDebuggerContinuesWhenATracepointIsEncountered {
    [_mode onTracepoint:_node];
    XCTAssertEqualObjects(_debugger.mode, _mode, @"Debugger did not change mode on encountering an arbitrary tracepoint");
}

- (void)testDebuggerIsPausedWhenABreakpointIsEncountered {
    [_debugger addBreakpoint:_node];
    [_mode onTracepoint:_node];
    XCTAssertEqualObjects([_debugger.mode class], [LKPauseMode class], @"Debugger switched to pause mode on breakpoint");
}

- (void)testDebuggerContinuesWhenTracingPastADeletedBreakpoint {
    [_debugger addBreakpoint:_node];
    [_debugger removeBreakpoint:_node];
    [_mode onTracepoint:_node];
    XCTAssertEqualObjects(_debugger.mode, _mode,
                          @"Debugger did not change modes on encountering a tracepoint where the breakpoint had been removed");
}
@end
