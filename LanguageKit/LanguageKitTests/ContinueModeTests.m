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
#import "LKLineBreakpointDescription.h"
#import "LKModule.h"
#import "LKPauseMode.h"

@interface ContinueModeTests : XCTestCase

@end

@implementation ContinueModeTests
{
    LKDebuggerService *_debugger;
    LKContinueMode *_mode;
    LKAST *_node;
    LKModule *_module;
    LKLineBreakpointDescription *_breakpoint;
}

- (void)setUp {
    _debugger = [LKDebuggerService new];
    _debugger.shouldStop = NO;
    _mode = _debugger.mode;
    _node = [LKComment commentWithString:@"// TODO: fix me"];
    _module = [LKModule module];
    _module.filename = @"foo.st";
    _node.parent = _module;
    _breakpoint = [[LKLineBreakpointDescription alloc] initWithFile:_node.module.filename
                                                               line:[_node sourceLine]];
}

- (void)tearDown {
    _debugger = nil;
    _mode = nil;
    _node = nil;
    _module = nil;
    _breakpoint = nil;
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

- (void)testDebuggerIsPausedWhenALineBreakpointIsEncountered {
    [_debugger addLineBreakpoint:_breakpoint];
    [_mode onTracepoint:_node];
    XCTAssertEqualObjects([_debugger.mode class], [LKPauseMode class], @"Debugger paused on encountering a line breakpoint");
}

- (void)testDebuggerContinuesWhenTracingPastADeletedLineBreakpoint {
    [_debugger addLineBreakpoint:_breakpoint];
    [_debugger removeLineBreakpoint:_breakpoint];
    [_mode onTracepoint:_node];
    XCTAssertEqualObjects(_debugger.mode, _mode,
                          @"Debugger did not change mode when it traced a point that is no longer a breakpoint");
}
@end
