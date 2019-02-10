#import "LKBlockExpr.h"
#import "LKLoop.h"
#import "LKMethod.h"

__thread void *unlabelledBreakBB;
__thread void *unlabelledContinueBB;

@implementation LKLoop
@synthesize label, statements, loopInitStatements, updateStatements, preCondition, postCondition;
+ (id) loopWithStatements:(NSMutableArray*)statementList
{
	return [[self alloc] initWithStatements:statementList];
}
- (id) initWithStatements:(NSMutableArray*)statementList
{
    self = [self init];
    if (self) {
        label = nil;
        loopInitStatements = nil;
        preCondition = nil;
        statements = statementList;
        postCondition = nil;
        updateStatements = nil;
    }
	return self;
}
- (BOOL) check
{
	for (LKAST *initStatement in loopInitStatements)
	{
		[initStatement setParent:self];
		if (![initStatement check]) return NO;
	}
	if (preCondition)
	{
		[preCondition setParent:self];
		if (![preCondition check]) return NO;
	}
	for (LKAST *statement in statements)
	{
		[statement setParent:self];
		if (![statement check]) return NO;
	}
	if (postCondition)
	{
		[postCondition setParent:self];
		if (![postCondition check]) return NO;
	}
	for (LKAST *updateStatement in updateStatements)
	{
		[updateStatement setParent:self];
		if (![updateStatement check]) return NO;
	}
	return YES;
}
- (NSString*) description
{
	NSMutableString *str = [NSMutableString string];
	for (LKAST *initStatement in loopInitStatements)
	{
		[str appendString:[initStatement description]];
		[str appendString:@".\n"];
	}
	if (label)
	{
		[str appendFormat:@"%@: [\n", label];
	}
	else
	{
		[str appendString:@"[\n"];
	}
	if (preCondition)
	{
		[str appendFormat:@"(%@) ifFalse: [ break ].\n", preCondition];
	}
	for (LKAST *statement in statements)
	{
		[str appendString:[statement description]];
		[str appendString:@".\n"];
	}
	if (postCondition)
	{
		[str appendFormat:@"(%@) ifFalse: [ break ].\n", postCondition];
	}
	for (LKAST *updateStatement in updateStatements)
	{
		[str appendString:[updateStatement description]];
		[str appendString:@".\n"];
	}
	[str appendString:@"] loop"];
	return str;
}
- (void*) compileWithGenerator:(id<LKCodeGenerator>)aGenerator
{
	void *entryBB = [aGenerator currentBasicBlock];
	void *startBB = [aGenerator startBasicBlock: @"loop_start"];
	void *bodyBB = [aGenerator startBasicBlock: @"loop_body"];
	void *continueBB = [aGenerator startBasicBlock: @"loop_continue"];
	void *breakBB = [aGenerator startBasicBlock: @"loop_break"];
	void *oldBreakBB = NULL;
	void *oldContinueBB = NULL;
	void *oldUnlabelledBreakBB = unlabelledBreakBB;
	void *oldUnlabelledContinueBB = unlabelledContinueBB;
	unlabelledBreakBB = breakBB;
	unlabelledContinueBB = continueBB;
	NSString *breakLabel = nil;
	NSString *continueLabel = nil;
	if (label)
	{
		breakLabel = [@"break " stringByAppendingString: label];
		continueLabel = [@"continue " stringByAppendingString: label];
		oldBreakBB = [aGenerator basicBlockForLabel: breakLabel];
		oldContinueBB = [aGenerator basicBlockForLabel: continueLabel];
		[aGenerator setBasicBlock: breakBB forLabel: breakLabel];
		[aGenerator setBasicBlock: continueBB forLabel: continueLabel];
	}
	// Entry point
	[aGenerator moveInsertPointToBasicBlock: entryBB];
	for (LKAST *initStatement in loopInitStatements)
	{
		[initStatement compileWithGenerator: aGenerator];
	}
	[aGenerator goToBasicBlock: startBB];
	// Emit pre condition
	[aGenerator moveInsertPointToBasicBlock: startBB];
	if (preCondition)
	{
		void *preValue = [preCondition compileWithGenerator: aGenerator];
		[aGenerator branchOnCondition: preValue true: bodyBB
		                                       false: breakBB];
	}
	else
	{
		[aGenerator goToBasicBlock: bodyBB];
	}
	// Emit loop body
	[aGenerator moveInsertPointToBasicBlock: bodyBB];
	BOOL addTerminator = YES;
	for (LKAST *statement in statements)
	{
		[statement compileWithGenerator: aGenerator];
		if ([statement isBranch])
		{
			addTerminator = NO;
			break;
		}
	}
	if (addTerminator)
	{
		if (postCondition)
		{
			void *postValue = [postCondition compileWithGenerator: aGenerator];
			[aGenerator branchOnCondition: postValue true: continueBB
			                                        false: breakBB];
		}
		else
		{
			[aGenerator goToBasicBlock: continueBB];
		}
	}
	// Emit continue block
	[aGenerator moveInsertPointToBasicBlock: continueBB];
	for (LKAST *updateStatement in updateStatements)
	{
		[updateStatement compileWithGenerator: aGenerator];
	}
	[aGenerator goToBasicBlock: startBB];
	unlabelledBreakBB = oldUnlabelledBreakBB;
	unlabelledContinueBB = oldUnlabelledContinueBB;
	if (label)
	{
		[aGenerator setBasicBlock: oldBreakBB forLabel: breakLabel];
		[aGenerator setBasicBlock: oldContinueBB forLabel: continueLabel];
	}
	[aGenerator moveInsertPointToBasicBlock: breakBB];
	return NULL;
}
- (void) visitWithVisitor:(id<LKASTVisitor>)aVisitor
{
	[self visitArray: loopInitStatements withVisitor: aVisitor];
	[preCondition visitWithVisitor: aVisitor];
	[self visitArray: statements withVisitor: aVisitor];
	[postCondition visitWithVisitor: aVisitor];
	[self visitArray: updateStatements withVisitor: aVisitor];
}
@end

@implementation LKLoopFlowControl
- (id) initWithLabel:(NSString*)aLabel
{
    self = [self init];
    if (self) {
        label = aLabel;
    }
	return self;
}
- (BOOL) check
{
	for (id ast = [self parent]; ast; ast = [ast parent])
	{
		if ([ast isKindOfClass: [LKBlockExpr class]] ||
		    [ast isKindOfClass: [LKMethod class]])
		{
			break;
		}
		if ([ast isKindOfClass: [LKLoop class]])
		{
			if (label == nil || [[ast label] isEqualToString: label])
			{
				return YES;
			}
		}
	}
/*  MUST REPLACE THIS WITH THE NEW ERROR REPORTING STUFF:

	[NSException raise: @"SemanticError"
	            format: @"%@ statement outside of loop construct, or matching label not found.",
	                    [[self flowControlFlavor] capitalizedString]];
*/
	return NO;
}
- (NSString*) description
{
	NSString *str = [self flowControlFlavor];
	if (label)
	{
		return [NSString stringWithFormat: @"%@ %@", str, label];
	}
	return str;
}
- (void*) compileWithGenerator:(id<LKCodeGenerator>)aGenerator
{
	[aGenerator goToLabelledBasicBlock:
		[NSString stringWithFormat:@"%@ %@", [self flowControlFlavor], label]];
	return NULL;
}
- (BOOL) isBranch
{
	return YES;
}
- (NSString*) flowControlFlavor
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}
@end

@implementation LKBreak
+ (id) breakWithLabel:(NSString*)aLabel
{
	return [[self alloc] initWithLabel: aLabel];
}
- (void*) compileWithGenerator:(id<LKCodeGenerator>)aGenerator
{
	if (label)
	{
		return [super compileWithGenerator: aGenerator];
	}
	[aGenerator goToBasicBlock: unlabelledBreakBB];
	return NULL;
}
- (NSString*) flowControlFlavor
{
	return @"break";
}
@end

@implementation LKContinue
+ (id) continueWithLabel:(NSString*)aLabel
{
	return [[self alloc] initWithLabel: aLabel];
}
- (void*) compileWithGenerator:(id<LKCodeGenerator>)aGenerator
{
	if (label)
	{
		return [super compileWithGenerator: aGenerator];
	}
	[aGenerator goToBasicBlock: unlabelledContinueBB];
	return NULL;
}
- (NSString*) flowControlFlavor
{
	return @"continue";
}
@end
