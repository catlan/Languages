//
//  InterpreterDebuggingTests.m
//  SmalltalkTests
//
//  Created by Graham Lee on 19/02/2019.
//

#import <XCTest/XCTest.h>
#import "LKAST.h"
#import "LKComment.h"
#import "LKContinueMode.h"
#import "LKDebuggerMode.h"
#import "LKDebuggerService.h"
#import "LKInterpreter.h"
#import "LKInterpreterContext.h"
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
    LKInterpreter *interpreter;
    LKDebuggerService *debugger;
    LKComment *node1;
    InspectableMode *mode;
    
}
- (void)setUp {
    table = [LKSymbolTable new];
    [table setTableScope:LKSymbolScopeGlobal];
    context = [[LKInterpreterContext alloc] initWithSymbolTable:table parent:nil];
    [[LKInterpreter interpreter] pushContext:context];
    mode = [InspectableMode new];
    debugger = [LKDebuggerService new];
    [debugger setMode:mode];
    [debugger activate];
    node1 = [LKComment commentWithString:@"# A comment"];
}

- (void)tearDown {
    [debugger deactivate];
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
    [debugger onTracepoint:node1 inContext: nil];
    XCTAssertEqualObjects([mode receivedNode], node1, @"onTracepoint: event forwarded to debugger mode");
}

- (void)testInterpretingAModuleStoresTheDebugger {
    LKModule *module = [LKModule module];
    [module interpretInContext:context];
    XCTAssertEqualObjects([LKInterpreter activeDebugger], debugger, @"Debugger was saved for later");
}

- (void)testDebuggerModeDefaultsToContinue {
    LKDebuggerService *otherService = [[LKDebuggerService alloc] init];
    XCTAssertEqualObjects([[otherService mode] class], [LKContinueMode class], @"Default mode is continue");
}
@end
