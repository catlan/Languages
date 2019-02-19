//
//  TracingTests.m
//  SmalltalkTests
//
//  Created by Graham Lee on 19/02/2019.
//

#import <XCTest/XCTest.h>

#import "LKArrayExpr.h"
#import "LKAST.h"
#import "LKIfStatement.h"
#import "LKInterpreter.h"
#import "LKToken.h"
#import "LKVariableDecl.h"

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

- (void)testVariableDeclGeneratesTracepoint {
    NSString *symbolName = @"symbol";
    LKToken *token = [LKToken tokenWithRange:NSMakeRange(0, [symbolName length])
                                    inSource:symbolName];
    LKVariableDecl *expr = [LKVariableDecl variableDeclWithName:token];
    [expr interpretInContext:context];
    XCTAssertEqualObjects([context lastNodeTraced], expr, @"Variable Decl generated a tracepoint");
}

- (void)testIfStatementGeneratesTracepoint {
    LKIfStatement *expr = [LKIfStatement ifStatementWithCondition:nil];
    [expr interpretInContext:context];
    XCTAssertEqualObjects([context lastNodeTraced], expr, @"If Statement generated a tracepoint");
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
