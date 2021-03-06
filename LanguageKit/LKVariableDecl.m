#import "LKVariableDecl.h"
#import "LKToken.h"
#import "Runtime/LKObject.h"

@implementation LKVariableDecl
- (LKVariableDecl*) initWithName: (LKToken*) declName
{
    self = [super init];
    if (self) {
        variableName = declName;
    }
	return self;
}
+ (LKVariableDecl*) variableDeclWithName:(LKToken*) declName
{
	return [[self alloc] initWithName:declName];
}
- (NSString*) description
{
	return [NSString stringWithFormat:@"var %@", variableName];
}
- (void) setParent:(LKAST*)aParent
{
	[super setParent:aParent];
	LKSymbol *sym = [LKSymbol new];
	[sym setName: variableName];
	[sym setTypeEncoding: NSStringFromRuntimeString(@encode(LKObject))];
	[sym setScope: LKSymbolScopeObject];
	[symbols addSymbol: sym];
}
- (NSString*)name
{
	return (NSString*)variableName;
}
- (BOOL) check { return YES; }
- (void*) compileWithGenerator: (id<LKCodeGenerator>)aGenerator
{
	return NULL;
}
@end
