//
//  TracingTests.m
//  SmalltalkTests
//
//  Created by Graham Lee on 19/02/2019.
//

#import <XCTest/XCTest.h>

#import "LanguageKit.h"
#import "LKInterpreter.h"
#import "LKToken.h"

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

#define EvaluateAndCheckForTracepoint(expr, msg) do { \
[expr interpretInContext:context]; \
XCTAssertEqualObjects([context lastNodeTraced], expr, msg); \
} while(NO)

- (void)testArrayExprGeneratesTracepoint {
    LKArrayExpr *expr = [LKArrayExpr arrayWithElements:@[]];
    EvaluateAndCheckForTracepoint(expr, @"Array Expr generated a tracepoint");
}

- (void)testVariableDeclGeneratesTracepoint {
    NSString *symbolName = @"symbol";
    LKToken *token = [LKToken tokenWithRange:NSMakeRange(0, [symbolName length])
                                    inSource:symbolName];
    LKVariableDecl *expr = [LKVariableDecl variableDeclWithName:token];
    EvaluateAndCheckForTracepoint(expr, @"Variable Decl generated a tracepoint");
}

- (void)testIfStatementGeneratesTracepoint {
    LKIfStatement *expr = [LKIfStatement ifStatementWithCondition:nil];
    EvaluateAndCheckForTracepoint(expr, @"If Statement generated a tracepoint");
}

- (void)testCompareGeneratesTracepoint {
    LKCompare *expr = [LKCompare comparisonWithLeftExpression:nil rightExpression:nil];
    EvaluateAndCheckForTracepoint(expr, @"Compare generated a tracepoint");
}

- (void)testStringLiteralGeneratesTracepoint {
    LKStringLiteral *expr = [LKStringLiteral literalFromString:@"literal"];
    EvaluateAndCheckForTracepoint(expr, @"String Literal generated a tracepoint");
}

- (void)testNumberLiteralGeneratesTracepoint {
    LKNumberLiteral *expr = [LKNumberLiteral literalFromString:@"3"];
    EvaluateAndCheckForTracepoint(expr, @"Number Literal generated a tracepoint");
}

- (void)testFloatLiteralGeneratesTracepoint {
    LKFloatLiteral *expr = [LKFloatLiteral literalFromString:@"3.14"];
    EvaluateAndCheckForTracepoint(expr, @"Float Literal generated a tracepoint");
}

- (void)testLoopGeneratesTracepoint {
    NSMutableArray *statements = [@[] mutableCopy];
    LKLoop *expr = [LKLoop loopWithStatements:statements];
    [expr setPreCondition:[LKNumberLiteral literalFromString:@"0"]];
    EvaluateAndCheckForTracepoint(expr, @"Loop generated a tracepoint");
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
