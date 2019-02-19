//
//  InterpreterDebuggingTests.m
//  SmalltalkTests
//
//  Created by Graham Lee on 19/02/2019.
//

#import <XCTest/XCTest.h>
#import "LKAST.h"
#import "LKComment.h"
#import "LKDebuggerService.h"
#import "LKInterpreter.h"

@interface InterpreterDebuggingTests : XCTestCase

@end

@implementation InterpreterDebuggingTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testInterpreterContextForwardsTracepointsToDebuggingService {
    LKSymbolTable *table = [LKSymbolTable new];
    [table setTableScope:LKSymbolScopeGlobal];
    LKInterpreterContext *context = [[LKInterpreterContext alloc] initWithSymbolTable:table parent:nil];
    LKDebuggerService *debugger = [LKDebuggerService new];
    [context debugWithService:debugger];
    LKComment *node1 = [LKComment commentWithString:@"# A comment"];
    [node1 interpretInContext:context];
    XCTAssertEqualObjects([debugger currentNode], node1, @"The current node in the debugger is the most recent to have been traced");
}
@end
