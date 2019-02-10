#import "LKComparison.h"

@implementation LKCompare
- (LKCompare*) initWithLeftExpression: (LKAST*)expr1
                      rightExpression: (LKAST*)expr2;
{
    self = [super init];
    if (self) {
        lhs = expr1;
        rhs = expr2;
    }
	return self;
}
+ (LKCompare*) comparisonWithLeftExpression: (LKAST*)expr1
					        rightExpression: (LKAST*)expr2;
{
	return [[LKCompare alloc] initWithLeftExpression:expr1
	                                  rightExpression: expr2];
}

- (id) leftExpression
{
    return lhs;
}

- (id) rightExpression
{
    return rhs;
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"%@ = %@", lhs, rhs];
}
- (BOOL)check
{
	[lhs setParent:self];
	[rhs setParent:self];
	return [lhs check] && [rhs check];
}
- (void*) compileWithGenerator: (id<LKCodeGenerator>)aGenerator
{
	void * l = [lhs compileWithGenerator: aGenerator];
	void * r = [rhs compileWithGenerator: aGenerator];
	return [aGenerator comparePointer:l to:r];
}
- (void) visitWithVisitor:(id<LKASTVisitor>)aVisitor
{
	id tmp = [aVisitor visitASTNode:lhs];
	lhs = tmp;
	[rhs visitWithVisitor:aVisitor];

	tmp = [aVisitor visitASTNode:rhs];
	rhs = tmp;
	[rhs visitWithVisitor:aVisitor];
}
@end
