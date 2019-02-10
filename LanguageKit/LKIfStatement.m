#import "LKIfStatement.h"
#import <EtoileFoundation/Macros.h>
#import "LKCodeGen.h"

@implementation LKIfStatement
- (LKIfStatement*) initWithCondition:(LKAST*) aCondition
                                then:(NSArray*)thenClause
                                else:(NSArray*)elseClause
{
	SUPERINIT;
	ASSIGN(condition, aCondition);
	thenStatements = [thenClause mutableCopy];
	elseStatements = [elseClause mutableCopy];
	return self;
}
+ (LKIfStatement*) ifStatementWithCondition:(LKAST*) aCondition
                                       then:(NSArray*)thenClause
                                       else:(NSArray*)elseClause
{
	return [[self alloc] initWithCondition: aCondition
	                                   then: thenClause
	                                   else: elseClause];
}

+ (LKIfStatement*) ifStatementWithCondition:(LKAST*) aCondition
{
	return [[self alloc] initWithCondition: aCondition
									  then: @[]
									  else: @[]];
}

static void *emitBlock(id<LKCodeGenerator> aGenerator, 
                       NSArray *statements,
                       void *continueBB,
                       NSString *bbname)
{
	void *bb = [aGenerator startBasicBlock: bbname];
	for (LKAST *statement in statements)
	{
		[statement compileWithGenerator: aGenerator];
		if ([statement isBranch])
		{
			return bb;
		}
	}
	[aGenerator goToBasicBlock: continueBB];
	return bb;
}

- (void) setElseStatements: (NSArray*)elseClause
{
	elseStatements = [elseClause mutableCopy];
}

- (void) setThenStatements: (NSArray*)thenClause
{
	thenStatements = [thenClause mutableCopy];
}

- (void*) compileWithGenerator: (id<LKCodeGenerator>)aGenerator
{
	void *compareValue = [condition compileWithGenerator: aGenerator];
	void *startBB = [aGenerator currentBasicBlock];
	void *continueBB = [aGenerator startBasicBlock: @"if_continue"];
	// Emit 'then' and 'else' clauses
	void *thenBB = 
		emitBlock(aGenerator, thenStatements, continueBB, @"if_then");
	void *elseBB = 
		emitBlock(aGenerator, elseStatements, continueBB, @"if_else");
	// Emit branch
	[aGenerator moveInsertPointToBasicBlock: startBB];
	[aGenerator branchOnCondition: compareValue true: thenBB false: elseBB];
	[aGenerator moveInsertPointToBasicBlock: continueBB];
	return NULL;
}
- (void) visitWithVisitor:(id<LKASTVisitor>)aVisitor
{
	id tmp = [aVisitor visitASTNode:condition];
	condition = tmp;
	[condition visitWithVisitor:aVisitor];
	[self visitArray:thenStatements withVisitor:aVisitor];
	[self visitArray:elseStatements withVisitor:aVisitor];
}
- (NSString*) description
{
	NSMutableString *str = [NSMutableString string];
	[str appendFormat:@"(%@)", condition];
	if (thenStatements)
	{
		[str appendString:@" ifTrue: [\n"];
		for (LKAST *thenStatement in thenStatements)
		{
			[str appendString:[thenStatement description]];
			[str appendString:@".\n"];
		}
		[str appendString:@"]"];
	}
	if (elseStatements)
	{
		[str appendString:@" ifFalse: [\n"];
		for (LKAST *elseStatement in elseStatements)
		{
			[str appendString:[elseStatement description]];
			[str appendString:@".\n"];
		}
		[str appendString:@"]"];
	}
	return str;
}
- (BOOL)check
{
	[condition setParent:self];
	BOOL success = [condition check];
    for (LKAST *thenStatement in thenStatements)
	{
		[thenStatement setParent:self];
		success &= [thenStatement check];
	}
    for (LKAST *elseStatement in elseStatements)
	{
		[elseStatement setParent:self];
		success &= [elseStatement check];
	}
	return success;
}
@end
