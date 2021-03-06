#import "LKSubclass.h"
#import "LKCompiler.h"
#import "LKCompilerErrors.h"
#import "LKModule.h"

@implementation LKSubclass
- (id) initWithName:(NSString*)aName
         superclass:(NSString*)aClass
              cvars:(NSArray*)aCvarList
              ivars:(NSArray*)anIvarList
         properties:(NSArray*)aPropertyList
            methods:(NSArray*)aMethodList
{
    self = [super init];
    if (self) {
        classname = aName;
        superclass = aClass;
        // catlan: register class early that the dependancy resolver in -check works
        symbols = [LKSymbolTable symbolTableForClass: classname];
        ivars = anIvarList != nil ? [anIvarList mutableCopy] : [NSMutableArray new];
        cvars = aCvarList != nil ? [aCvarList mutableCopy] : [NSMutableArray new];
        properties = aPropertyList != nil ? [aPropertyList mutableCopy] : [NSMutableArray new];
        methods = aMethodList != nil ? [aMethodList mutableCopy] : [NSMutableArray new];
    }
	return self;
}
+ (id) subclassWithName:(NSString*)aName
        superclassNamed:(NSString*)aClass
                  cvars:(NSArray*)aCvarList
                  ivars:(NSArray*)anIvarList
             properties:(NSArray*)aPropertyList
                methods:(NSArray*)aMethodList
{
	return [[self alloc] initWithName: aName
	                        superclass: aClass
	                             cvars: aCvarList
	                             ivars: anIvarList
                            properties: aPropertyList
	                           methods: aMethodList];
}
- (BOOL)check
{
	BOOL success = YES;
	LKSymbolTable* superSymTable = [LKSymbolTable lookupTableForClass: superclass];
    // catlan: need to figure out where symbols gets set to nil between -init and -check.
	symbols = [LKSymbolTable symbolTableForClass: classname]; 
	if (Nil == superSymTable)
	{
        NSDictionary *errorDetails = nil;
        errorDetails = [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSString stringWithFormat:
                         @"Attempting to subclass un unknown superclasss: %@", superclass],
                        kLKHumanReadableDescription,
                        self, kLKASTNode,
                        nil];
	  if ([LKCompiler reportError: LKUndefinedSuperclassError
							details: errorDetails] == NO)
	  {
		  return NO;
	  }
	}
	[symbols setEnclosingScope: superSymTable];
	//Construct symbol table.
	if (Nil != NSClassFromString(classname))
	{
        NSDictionary *errorDetails = nil;
        errorDetails = [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSString stringWithFormat:
                         @"Attempting to create class which already exists: %@", classname],
                        kLKHumanReadableDescription,
                        self, kLKASTNode,
                        nil];
		success &= [LKCompiler reportWarning: LKRedefinedClassWarning
		                             details: errorDetails];
	}
	//Construct symbol table.
	[symbols addSymbolsNamed: ivars ofKind: LKSymbolScopeObject];
	[symbols addSymbolsNamed: cvars ofKind: LKSymbolScopeClass];
	for (LKSymbol *s in [symbols classVariables])
	{
		[s setOwner: self];
	}
	for (LKSymbol *s in [symbols instanceVariables])
	{
		[s setOwner: self];
	}
	// Check the methods
    for (LKAST *method in methods)
	{
		[method setParent:self];
		success &= [method check];
	}
	return success;
}
- (NSString*) description
{
	NSMutableString *str = 
		[NSMutableString stringWithFormat:@"%@ subclass: %@ [ \n",
			superclass, classname];
	if ([ivars count])
	{
		[str appendString:@"| "];
		for (NSString *ivar in ivars)
		{
			[str appendFormat:@"%@ ", ivar];
		}
		[str appendString:@"|\n"];
	}
	for (LKAST *method in methods)
	{
		[str appendString:[method description]];
		[str appendString: @"\n"];
	}
	[str appendString:@"\n]"];
	return str;
}
- (void*) compileWithGenerator: (id<LKCodeGenerator>)aGenerator
{
	[aGenerator createSubclassWithName: classname
	                   superclassNamed: superclass
	                   withSymbolTable: symbols];
    for (LKAST *method in methods)
	{
		[method compileWithGenerator: aGenerator];
	}
	if ([ivars count] > 0)
	{
		// Emit the .cxx_destruct method that cleans up ivars
		// -.cxx_destruct has the same types as -dealloc, but if we're not
		// linking against any ARC code then it's quite likely that we don't
		// actually have any classes implementing -.cxx_destruct, so we can't
		// ask for the types from the runtime and get a sensible answer.
		NSString *type = [[[self module] typesForMethod: @"dealloc"] objectAtIndex: 0];
		[aGenerator beginInstanceMethod: @".cxx_destruct"
					   withTypeEncoding: type
							  arguments: nil
								 locals: nil];
		void *nilValue = [aGenerator nilConstant];
		for (NSString *ivarName in ivars)
		{
			LKSymbol *ivar = [symbols symbolForName: ivarName];
			[aGenerator storeValue: nilValue inVariable: ivar];
		}
		[aGenerator endMethod];
	}
	[aGenerator endClass];
	if ([[LKAST code] objectForKey: classname] == nil)
	{
		[[LKAST code] setObject: [NSMutableArray array] forKey: classname];
	}
	[[[LKAST code] objectForKey: classname] addObject: self];
	return NULL;
}
- (void) visitWithVisitor:(id<LKASTVisitor>)aVisitor
{
	[self visitArray: methods withVisitor: aVisitor];
}
- (NSString*) classname
{
	return classname;
}
- (NSString*) superclassname
{
	return superclass;
}
- (NSMutableArray*)methods
{
	return methods;
}
- (void)addInstanceVariable: (NSString*)anIvar
{
	[ivars addObject: anIvar];
}
- (NSArray*)instanceVariables
{
	return ivars;
}
- (NSArray*)classVariables
{
	return cvars;
}
- (NSArray*)properties
{
    return properties;
}
@end
