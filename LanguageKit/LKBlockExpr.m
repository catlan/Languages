#import "LKBlockExpr.h"
#import "LKDeclRef.h"
#import "Runtime/LKObject.h"

@implementation LKBlockExpr
@synthesize arguments, locals;
+ (id) blockWithArguments:(NSMutableArray<LKVariableDecl *>*)arguments locals:(NSMutableArray<LKVariableDecl *>*)locals statements:(NSMutableArray*)statementList
{
	return [[self alloc] initWithArguments: arguments
	                                 locals: locals
	                             statements: statementList];
}
- (id) initWithArguments: (NSMutableArray<LKVariableDecl *>*)argumentList
                  locals: (NSMutableArray<LKVariableDecl *>*)localVarList
              statements: (NSMutableArray*)statementList
{
	LKSymbolTable *table = [LKSymbolTable new];
	[table setDeclarationScope: self];
	[table addSymbolsNamed: localVarList ofKind: LKSymbolScopeLocal];
	[table addSymbolsNamed: argumentList ofKind: LKSymbolScopeArgument];
	self = [super initWithSymbolTable: table];
	if (self != nil)
	{
        ASSIGN(arguments, argumentList);
        ASSIGN(locals, localVarList);
		ASSIGN(statements, statementList);
	}
	return self;
}
- (void) setStatements: (NSMutableArray*)anArray
{
	ASSIGN(statements, anArray);
}
- (BOOL)check
{
	BOOL success = YES;
	for (LKAST *s in statements)
	{
		[s setParent:self];
		success &= [s check];
	}
	return success;
}
- (NSString*) description
{
	NSMutableString *str = [NSMutableString string];
	[str appendString:@"[ "];
	if (0 != [[symbols arguments] count])
	{
		for (LKSymbol *s in [symbols arguments])
		{
			[str appendFormat:@":%@ ", s];
		}
		[str appendString:@"| "];
		[str appendString:@"\n"];
	}
	if (0 != [[symbols locals] count])
	{
		[str appendString:@"| "];
		for (LKSymbol *s in [symbols locals])
		{
			[str appendFormat: @"%@ ", s];
		}
		[str appendString: @"|\n"];
	}
	for (LKAST *statement in statements)
	{
		[str appendString:[statement description]];
		[str appendString:@".\n"];
	}
	[str appendString:@"]"];
	return str;
}
- (void*) compileWithGenerator: (id<LKCodeGenerator>)aGenerator
{
	NSArray *args = [symbols arguments];
	NSUInteger argCount = [args count];
	// FIXME: We should be able to generate other block signatures
	NSMutableString *sig =
        [NSMutableString stringWithFormat: @"%s%lu@?", @encode(NSObject *), sizeof(id) * (argCount+1)];
	for (NSUInteger i=0 ; i<argCount ; i++)
	{
        [sig appendFormat: @"%lu%s", sizeof(id)*i, @encode(NSObject *)];
	}
	[aGenerator beginBlockWithArgs: args
	                        locals: [symbols locals]
	                     externals: [symbols byRefVariables]
	                     signature: sig];
	void * lastValue = NULL;
	BOOL addBranch = YES;
	for (LKAST *statement in statements)
	{
		if (![statement isComment])
		{
			lastValue = [statement compileWithGenerator: aGenerator];
			if ([statement isBranch])
			{
				addBranch = NO;
				break;
			}
		}
	}
	if (addBranch)
	{
		[aGenerator blockReturn: lastValue];
	}
	return [aGenerator endBlock];
}
- (void) inheritSymbolTable:(LKSymbolTable*)aSymbolTable
{
	[symbols setEnclosingScope: aSymbolTable];
}
- (void) visitWithVisitor:(id<LKASTVisitor>)aVisitor
{
	[self visitArray:statements withVisitor:aVisitor];
}
- (NSMutableArray*) statements
{
	return statements;
}
@end
