//
//  LanguageKitTests.m
//  LanguageKitTests
//
//  Created by Christopher Atlan on 16.02.19.
//

#import <XCTest/XCTest.h>

#import <LanguageKit/LanguageKit.h>

@interface LanguageKitTests : XCTestCase {
    LKDBServer *_server;
}

@end

@implementation LanguageKitTests

- (void)setUp {
    _server = [[LKDBServer alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testDBClient {
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:@"addBreakpoint"];
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:@"removeBreakpoint"];
    LKDBClient *client = [[LKDBClient alloc] init];
    [client addBreakpoint:@"Hello World" withReply:^(id obj, NSError *error) {
        
        XCTAssertEqualObjects(@"World", obj, @"");
        XCTAssertNil(error, @"");
        [expectation1 fulfill];
        
    }];
    [client removeBreakpoint:@"Hello World" withReply:^(id obj, NSError *error) {
        
        XCTAssertEqualObjects(@"World", obj, @"");
        XCTAssertNil(error, @"");
        [expectation2 fulfill];
        
    }];
    [self waitForExpectations:[NSArray arrayWithObjects:expectation1, expectation2, nil] timeout:10.0];
}


@end
