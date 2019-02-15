//
//  SmalltalkTests.m
//  SmalltalkTests
//
//  Created by Christopher Atlan on 26.06.18.
//

#import <XCTest/XCTest.h>

#import <LanguageKit/LanguageKit.h>
#import <Smalltalk/Smalltalk.h>



@interface SmalltalkTests : XCTestCase
//@property id<LKParser> parser;
//@property LKAST *module;
@end

@interface SmalltalkTests (Smalltalk)
- (id)classMethodInvocation;
- (NSArray *)arrayLiterals;
- (NSNumber *)pie;
- (NSNumber *)negativeOne;
- (NSNumber *)negativeOnePointTwoThree;
- (NSNumber *)onePlusTwo;
- (NSNumber *)threePlusFourTimesFive;
- (NSNumber *)fourThirdsTimesThreeEqualsFour;
- (NSString *)stringForIfNil;
- (NSString *)stringForIfNilIfNotNilBranch1;
- (NSString *)stringForIfNilIfNotNilBranch2;
- (NSString *)stringForIfNotNil;
- (NSString *)stringForIfNotNilIfNilBranch1;
- (NSString *)stringForIfNotNilIfNilBranch2;
@end

@interface SmalltalkSubclassTests : NSObject
- (NSString *)var1;
@end

@interface SmalltalkSubSubclassTests : SmalltalkSubclassTests
- (NSString *)var2;
@end

//static LKSymbolTable *_globalSymbolTable;
static LKAST *_module = nil;
static NSMutableArray *LogMessage;

@implementation SmalltalkTests

+ (void)setUp
{
    [super setUp];
    
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:[self className] ofType:@"st"];
    NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    id<LKParser> parser = parser = [[[LKCompiler compilerClassForFileExtension:@"st"] parserClass] new];
    
    //_globalSymbolTable = [[LKSymbolTable alloc] init];
    _module = [parser parseString:source];
    //[_module inheritSymbolTable:_globalSymbolTable];
    if (![_module check])
    {
        return;
    }
    [_module interpretInContext: nil];
}

+ (void)tearDown
{
    [super tearDown];
    
    _module = nil;
}


+ (void)show:(NSString *)string
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LogMessage = [NSMutableArray array];
    });
    [LogMessage addObject:string];
}


- (void)testClassMethodInvocation
{
    [self classMethodInvocation];
    
    XCTAssertEqualObjects(@"class method invocation [SmalltalkTests show:]", [LogMessage objectAtIndex:0], @"");
    XCTAssertEqualObjects(@"class method invocation [self class show:]", [LogMessage objectAtIndex:1], @"");
}

- (void)testNumberLiterals
{
    XCTAssertEqualObjects(@(-1), [self negativeOne], @"should equal -1");
    XCTAssertEqualWithAccuracy(-1.23, [[self negativeOnePointTwoThree] doubleValue], 0.000000001, @"should equal -1.23");
    XCTAssertEqualWithAccuracy(3.141592653589793238, [[self pie] doubleValue], 0.000000001, @"should equal 3.141592653589793238");
}

- (void)testArrayLiterals
{
    NSArray *result = [self arrayLiterals];
    XCTAssertEqualObjects(@(1), [result objectAtIndex:0], @"should equal 1");
    XCTAssertEqualObjects(@(2), [result objectAtIndex:1], @"should equal 2");
    XCTAssertEqualObjects(@(3), [result objectAtIndex:2], @"should equal 3");
}

- (void)testBinaryMessages
{
    NSNumber *result = nil;
    result = [self onePlusTwo];
    XCTAssertEqualObjects(result, @(3), @"should equal 3");
    // Binary messages are always parsed left to right, without regard to precedence of numeric operators, unless corrected with parentheses.
    // 3 + 4 * 5 " ==> 35 (not 23) 
    result = [self threePlusFourTimesFive];
    XCTAssertEqualObjects(result, @(35), @"should equal 27");
#warning Test mssing
    // The implementation for -[BigInt div:] is mpz_tdiv_q which only gives the quotient and throws away the remainder. The fix is to replace that method with one that generates a rational, but the rational type isn’t exposed in the runtime.
    //result = [self fourThirdsTimesThreeEqualsFour];
    //XCTAssertEqualObjects(result, @(YES), @"equality is just a binary message, and Fractions are exact");
}

- (void)testControlStructures
{
    NSString *result = nil;
    result = [self stringForIfNil];
    XCTAssertEqualObjects(@"test is nil", result, @"");
    result = [self stringForIfNilIfNotNilBranch1];
    XCTAssertEqualObjects(@"test is nil", result, @"");
    result = [self stringForIfNilIfNotNilBranch2];
    XCTAssertEqualObjects(@"test is NOT nil", result, @"");
    result = [self stringForIfNotNil];
    XCTAssertEqualObjects(@"test is NOT nil", result, @"");
    result = [self stringForIfNotNilIfNilBranch1];
    XCTAssertEqualObjects(@"test is NOT nil", result, @"");
    result = [self stringForIfNotNilIfNilBranch2];
    XCTAssertEqualObjects(@"test is nil", result, @"");
}

- (void)testSubclasses
{
    SmalltalkSubclassTests *obj1 = [[NSClassFromString(@"SmalltalkSubclassTests") alloc] init];
    XCTAssertNotNil(obj1, @"");
    XCTAssertEqualObjects(@"Hello", [obj1 var1], @"");
    
    SmalltalkSubSubclassTests *obj2 = [[NSClassFromString(@"SmalltalkSubSubclassTests") alloc] init];
    XCTAssertNotNil(obj2, @"");
    XCTAssertEqualObjects(@"Hello", [obj2 var1], @"");
    XCTAssertEqualObjects(@"World", [obj2 var2], @"");
}

@end
