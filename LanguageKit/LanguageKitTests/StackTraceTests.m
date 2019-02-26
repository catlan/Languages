//
//  StackTraceTests.m
//  LanguageKitTests
//
//  Created by Graham Lee on 26/02/2019.
//

#import <XCTest/XCTest.h>

#import "LKDebuggerService.h"
#import "LKCategory.h"
#import "LKComment.h"
#import "LKDeclRef.h"
#import "LKMessageSend.h"
#import "LKMethod.h"
#import "LKModule.h"
#import "LKReturn.h"

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

- (void)testStackTraceContainsNoLanguageKitSymbols {
    [debugger onTracepoint:nil inContext:nil];
    [debugger pause];
    NSArray <NSString *>* stacktrace = [debugger stacktrace];
    NSPredicate *containsLKMethod = [NSPredicate predicateWithBlock:^BOOL(NSString * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject containsString:@"[LK"];
    }];
    NSArray <NSString *>* languageKitMethods = [stacktrace filteredArrayUsingPredicate:containsLKMethod];
    XCTAssertEqual([languageKitMethods count], 0, @"The interpreter doesn't show up in its own stack trace");
}

- (void)testTopOfTheCallStackContainsTheInterpreterStack {
    /* build a non-trivial syntax "tree"
     * this module adds a method -[NSObject(Methods) doAThing] that returns nil
     */
    LKReturn *retStatement = [LKReturn returnWithExpr:[LKNilRef builtin]];
    LKMessageSend *signature = [LKMessageSend messageWithSelectorName:@"doAThing"];
    LKMethod *method = [LKInstanceMethod methodWithSignature:signature
                                                      locals:nil
                                                  statements:[@[retStatement] mutableCopy]];
    LKCategoryDef *category = [LKCategoryDef categoryWithName:@"Methods"
                                                 onClassNamed:@"NSObject"
                                                      methods:@[method]];
    LKModule *module = [LKModule module];
    [module addCategory:(LKCategory *)category]; // this is a bug in LKModule.h
    [retStatement setParent:method];
    [method setParent:category];
    [category setParent:module];
    [debugger onTracepoint:retStatement inContext:nil];
    [debugger pause];
    NSString *topOfStack = [debugger stacktrace][0];
    XCTAssertEqualObjects(topOfStack, @"<Interpreted>        -[NSObject(Methods) doAThing]", @"Our method appears on top");
}
@end
