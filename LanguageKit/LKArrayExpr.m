#import "LKArrayExpr.h"
#import "LKModule.h"

@implementation LKArrayExpr
@synthesize elements;
+ (id) arrayWithElements:(NSArray*)anArray
{
	return [[self alloc] initWithElements: anArray];
}
- (id) initWithElements:(NSArray*)anArray
{
    self = [super init];
    if (self) {
        elements = [anArray mutableCopy];
    }
	return self;
}
- (BOOL)check
{
	BOOL success = YES;
	for (LKAST *element in elements)
	{
		[element setParent:self];
		success &= [element check];
	}
	return success;
}
- (NSString*) description
{
	NSMutableString *str = [NSMutableString stringWithString:@"#("];
    for (LKAST *element in elements)
	{
		[str appendFormat:@"%@, ", [element description]];
	}
	[str replaceCharactersInRange:NSMakeRange([str length] - 2, 2) withString:@")"];
	return str;
}
- (void*) compileWithGenerator: (id<LKCodeGenerator>)aGenerator
{
	void *values[[elements count] + 1];
	int i = 0;
    for (LKAST *element in elements)
	{
		values[i++] = [element compileWithGenerator: aGenerator];
	}
	values[i++] = [aGenerator nilConstant];
	void *arrayClass = [aGenerator loadClassNamed:@"NSMutableArray"];
	return [aGenerator sendMessage: @"arrayWithObjects:"
	                         types: NULL
	                      toObject: arrayClass
	                      withArgs: values
	                         count: i];
}
- (void) visitWithVisitor:(id<LKASTVisitor>)aVisitor
{
	[self visitArray:elements withVisitor:aVisitor];
}
@end
