#import <LanguageKit/LKAST.h>

@interface LKCompare : LKAST {
	LKAST *lhs;
	LKAST *rhs;
}
+ (LKCompare*) comparisonWithLeftExpression: (LKAST*)expr1
					        rightExpression: (LKAST*)expr2;

/**
 * Return the left hand expression
 */
- (id) leftExpression;

/**
 * Return the right hand expression
 */
- (id) rightExpression;

@end
