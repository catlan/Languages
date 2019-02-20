//
//  InterpreterDebuggingTests.m
//  SmalltalkTests
//
//  Created by Graham Lee on 19/02/2019.
//

#import <XCTest/XCTest.h>
#import "LKAST.h"
#import "LKComment.h"
#import "LKDebuggerMode.h"
#import "LKDebuggerService.h"
#import "LKInterpreter.h"
#import "LKModule.h"

@interface InspectableMode : NSObject <LKDebuggerMode>

- (LKAST *)receivedNode;

@end

@implementation InspectableMode
{
    LKAST *lastNode;
}

@synthesize service;

- (void)onTracepoint: (LKAST *)aNode
{
    lastNode = aNode;
}

- (LKAST *)receivedNode
{
    return lastNode;
}

@end

@interface InterpreterDebuggingTests : XCTestCase

@end

@implementation InterpreterDebuggingTests
{
    LKSymbolTable *table;
    LKInterpreterContext *context;
    LKDebuggerService *debugger;
    LKComment *node1;
    InspectableMode *mode;
    
}
- (void)setUp {
    table = [LKSymbolTable new];
    [table setTableScope:LKSymbolScopeGlobal];
    context = [[LKInterpreterContext alloc] initWithSymbolTable:table parent:nil];
    mode = [InspectableMode new];
    debugger = [LKDebuggerService new];
    [debugger setMode:mode];
    [context setDebugger:debugger];
    node1 = [LKComment commentWithString:@"# A comment"];
    [LKInterpreterContext setActiveDebugger:nil];
}

- (void)tearDown {
    [LKInterpreterContext setActiveDebugger:nil];
    table = nil;
    context = nil;
    debugger = nil;
    node1 = nil;
    mode = nil;
}

- (void)testInterpreterContextForwardsTracepointsToDebuggingService {
    [node1 interpretInContext:context];
    XCTAssertEqualObjects([debugger currentNode], node1, @"The current node in the debugger is the most recent to have been traced");
}

- (void)testDebuggingServiceGivesModeAReferenceToItself {
    XCTAssertEqualObjects([mode service], debugger, @"Debugger service gave its mode a reference to itself");
}

- (void)testDebuggingServiceForwardsTracepointEventsToMode {
    [debugger setMode:mode];
    [debugger onTracepoint:node1];
    XCTAssertEqualObjects([mode receivedNode], node1, @"onTracepoint: event forwarded to debugger mode");
}

- (void)testInterpretingAModuleStoresTheDebugger {
    LKModule *module = [LKModule module];
    [module interpretInContext:context];
    XCTAssertEqualObjects([LKInterpreterContext activeDebugger], debugger, @"Debugger was saved for later");
}
@end
