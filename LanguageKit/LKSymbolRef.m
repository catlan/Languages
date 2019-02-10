#import "LKSymbolRef.h"

@implementation LKSymbolRef
- (id) initWithSymbol:(NSString*)sym
{
    self = [super init];
    if (self) {
        symbol = sym;
    }
	return self;
}
+ (id) referenceWithSymbol:(NSString*)sym
{
	return [[self alloc] initWithSymbol: sym];
}
- (BOOL) check { return YES; }
- (NSString*) description
{
	return [NSString stringWithFormat:@"#%@", symbol];
}
- (void*) compileWithGenerator: (id<LKCodeGenerator>)aGenerator
{
	return [aGenerator generateConstantSymbol:symbol];
}
@end
