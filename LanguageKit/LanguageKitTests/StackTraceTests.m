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

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testEncounteringASTNodeInTheDebuggerCapturesThreadObject {
    NSThread *currentThread = [NSThread currentThread];
    LKComment *comment = [LKComment commentWithString:@""];
    LKDebuggerService *debugger = [[LKDebuggerService alloc] init];
    [debugger onTracepoint:comment inContext:nil];
    XCTAssertEqualObjects([debugger executingThread], currentThread, @"Thread was stored");
}

@end
