//
//  TracingTests.m
//  SmalltalkTests
//
//  Created by Graham Lee on 19/02/2019.
//

#import <XCTest/XCTest.h>

#import "LanguageKit.h"
#import "LKInterpreterContext.h"
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
    LKSymbolTable *table;
    LKSymbol *symbol;
}

- (void)setUp {
    table = [LKSymbolTable new];
    NSString *name = @"symbol";
    symbol = [LKSymbol new];
    symbol.name = name;
    symbol.scope = LKSymbolScopeLocal;
    symbol.typeEncoding = @"@";
    [table setTableScope:LKSymbolScopeLocal];
    [table addSymbol:symbol];
    context = [[FakeInterpreterContext alloc] initWithSymbolTable:table parent:nil];
}

- (void)tearDown {
    context = nil;
    table = nil;
    symbol = nil;
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

- (void)testReturnGeneratesTracepoint {
    LKReturn *expr = [LKReturn returnWithExpr:nil];
    EvaluateAndCheckForTracepoint(expr, @"Return generated a tracepoint");
}

- (void)testSubclassGeneratesTracepoint {
    LKSubclass *expr = [LKSubclass subclassWithName:@"MyArray"
                                    superclassNamed:@"NSArray"
                                              cvars:nil
                                              ivars:nil
                                         properties:nil
                                            methods:nil];
    EvaluateAndCheckForTracepoint(expr, @"Subclass generated a tracepoint");
}

- (void)testMessageSendGeneratesTracepoint {
    LKMessageSend *expr = [LKMessageSend messageWithSelectorName:@"count"];
    EvaluateAndCheckForTracepoint(expr, @"Message Send generated a tracepoint");
}

- (void)testNilCheckMessageSendsGenerateTracepoint {
    LKMessageSend *expr = [LKMessageSend messageWithSelectorName:@"ifNil:"];
    EvaluateAndCheckForTracepoint(expr, @"sending -ifNil: can be traced");
    expr = [LKMessageSend messageWithSelectorName:@"ifNotNil:"];
    EvaluateAndCheckForTracepoint(expr, @"sending -ifNotNil: can be traced");
    expr = [LKMessageSend messageWithSelectorName:@"ifNil:ifNotNil:"];
    EvaluateAndCheckForTracepoint(expr, @"sending -ifNil:ifNotNil: can be traced");
    expr = [LKMessageSend messageWithSelectorName: @"ifNotNil:ifNil:"];
    EvaluateAndCheckForTracepoint(expr, @"sending -ifNotNil:ifNil: can be traced");
}

- (void)testMessageCascadeGeneratesTracepoint {
    LKMessageCascade *expr = [LKMessageCascade messageCascadeWithTarget:nil messages:nil];
    EvaluateAndCheckForTracepoint(expr, @"Message Cascade generated a tracepoint");
}

- (void)testModuleGeneratesTracepoint {
    LKModule *expr = [LKModule module];
    EvaluateAndCheckForTracepoint(expr, @"Method generated a tracepoint");
}

- (void)testBlockExpressionGeneratesTracepoint {
    LKBlockExpr *expr = [LKBlockExpr blockWithArguments:nil
                                                 locals:nil
                                             statements:nil];
    EvaluateAndCheckForTracepoint(expr, @"Block Expr generated a tracepoint");
}

- (void)testCategoryDefGeneratesTracepoint {
    LKCategoryDef *expr = [LKCategoryDef categoryOnClassNamed:@"NSObject" methods:nil];
    EvaluateAndCheckForTracepoint(expr, @"Category Def generated a tracepoint");
}

- (void)testLocalDeclRefGeneratesTracepoint {
    /* internally a LKDeclRef converts its string argument into a symbol,
     * at some point in its lifecycle. It needs to happen before interpretation,
     * so here I just set it up with a symbol.
     */
    LKDeclRef *expr = [LKDeclRef referenceWithSymbol:(id)symbol];
    EvaluateAndCheckForTracepoint(expr, @"local Decl Ref generated a tracepoint");
}

- (void)testAssignExprGeneratesTracepoint {
    LKDeclRef *decl = [LKDeclRef referenceWithSymbol:(id)symbol];
    LKAssignExpr *expr = [LKAssignExpr assignWithTarget:decl expr:nil];
    EvaluateAndCheckForTracepoint(expr, @"Assign Expr generated a tracepoint");
}

- (void)testCommentGeneratesTracepoint {
    LKComment *expr = [LKComment commentWithString:@"/* you are not expected to understand this. */"];
    EvaluateAndCheckForTracepoint(expr, @"Comment generated a tracepoint");
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
