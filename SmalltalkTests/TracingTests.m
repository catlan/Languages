//
//  TracingTests.m
//  SmalltalkTests
//
//  Created by Graham Lee on 19/02/2019.
//

#import <XCTest/XCTest.h>

#import "LKArrayExpr.h"
#import "LKAST.h"
#import "LKInterpreter.h"

// subclass the interpreter context to inspect the messages it receives
@interface FakeInterpreterContext : LKInterpreterContext

- (void)onTracepoint:(LKAST *)aNode;
- (LKAST *)lastNodeTraced;

@end

@interface TracingTests : XCTestCase

@end

@implementation TracingTests
{
    FakeInterpreterContext *context;
}

- (void)setUp {
    context = [FakeInterpreterContext new];
}

- (void)tearDown {
    context = nil;
}

- (void)testArrayExprGeneratesTracepoint {
    LKArrayExpr *expr = [LKArrayExpr arrayWithElements:@[]];
    [expr interpretInContext:context];
    XCTAssertEqualObjects([context lastNodeTraced], expr, @"Array Expression generated a tracepoint");
}

@end

@implementation FakeInterpreterContext
{
    LKAST *lastNode;
}

- (void)onTracepoint:(LKAST *)aNode
{
    lastNode = aNode;
}

- (LKAST *)lastNodeTraced
{
    return lastNode;
}

@end
