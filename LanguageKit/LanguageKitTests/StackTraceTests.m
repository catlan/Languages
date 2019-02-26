//
//  StackTraceTests.m
//  LanguageKitTests
//
//  Created by Graham Lee on 26/02/2019.
//

#import <XCTest/XCTest.h>

#import "LKDebuggerService.h"
#import "LKComment.h"

@interface StackTraceTests : XCTestCase

@end

@implementation StackTraceTests
{
    LKComment *comment;
    LKDebuggerService *debugger;
}

- (void)setUp {
    comment = [LKComment commentWithString:@""];
    debugger = [LKDebuggerService new];
    debugger.shouldStop = NO;
}

- (void)tearDown {
    comment = nil;
    debugger = nil;
}

- (void)testEvenWithNoScriptRunningTheStacktraceIsNotEmpty {
    /*
     * This test captures an important design choice: that the stack trace
     * from the debugger includes whatever native code led up to the point where
     * the interpreter was invoked. Otherwise, with no script running, the stack
     * trace would be empty.
     *
     * It needs to be an asynchronous test, because we need to pause the debugger
     * on one thread and ask for its stack trace on another.
     */
    [debugger onTracepoint:nil inContext:nil];
    [debugger pause];
    NSArray <NSString *>* stacktrace = [debugger stacktrace];
    XCTAssertNotNil(stacktrace, @"definitely got an object");
    XCTAssertNotEqualObjects(stacktrace, @[], @"stacktrace was not empty");
}
@end
