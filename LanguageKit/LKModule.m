#import "LKModule.h"
#import "LKSubclass.h"
#import "LKCompilerErrors.h"
#import "Runtime/LKObject.h"
#import <objc/runtime.h>

/**
 * Maps method names to type encodings, gathered by iterating through all
 * methods in all classes. Needed only on the Mac runtime, which
 * doesn't have a function for looking up the types given a selector.
 */
static NSMutableDictionary *Types = nil;
static NSMutableDictionary *SelectorConflicts = nil;
NSString *LKCompilerDidCompileNewClassesNotification = 
	@"LKCompilerDidCompileNewClassesNotification";

SEL sel_get_any_typed_uid(const char *name);

#if defined(__GNUSTEP_RUNTIME__)
static NSArray *TypesForMethodName(NSString *methodName)
{
	const char *buffer[16];
	unsigned int count = sel_copyTypes_np([methodName UTF8String], buffer, 16);
	const char **types = buffer;
	if (count > 16)
	{
		types = calloc(count, sizeof(char*));
		sel_copyTypes_np([methodName UTF8String], buffer, count);
	}
	NSMutableArray *typeStrings = [NSMutableArray new];
	for (unsigned int i=0 ; i<count ; i++)
	{
		[typeStrings addObject: NSStringFromRuntimeString(types[i])];
	}
	if (buffer != types)
	{
		free(types);
	}
	return typeStrings;
}
#else
static NSArray* TypesForMethodName(NSString *methodName)
{
    id object = [Types objectForKey: methodName];
    if (object)
    {
        if ([object isKindOfClass:[NSArray class]])
             return object;
        return [NSArray arrayWithObject:object];
    }
	return nil;
}
#endif

@implementation LKModule 
+ (void) initialize
{
	if (self != [LKModule class])
	{
		return;
	}
	// Look up potential selector conflicts.
	Types = [NSMutableDictionary new];
	SelectorConflicts = [NSMutableDictionary new];
	
	unsigned int numClasses = objc_getClassList(NULL, 0);
	Class *classes = NULL;
	if (numClasses > 0)
	{
		classes = (__unsafe_unretained Class*)malloc(sizeof(Class) * numClasses);
		numClasses = objc_getClassList(classes, numClasses);
	}
	
	for (unsigned int classIndex=0; classIndex<numClasses; classIndex++)
	{
		unsigned int methodCount;
		Method *methods = class_copyMethodList(classes[classIndex], &methodCount);
		for (unsigned int i=0 ; i<methodCount ; i++)
		{
			Method m = methods[i];

			NSString *name = NSStringFromRuntimeString(sel_getName(method_getName(m)));
			NSString *type = NSStringFromRuntimeString(method_getTypeEncoding(m));
            
            id old = [Types objectForKey: name];
            if (nil == old)
            {
                [Types setObject: type forKey: name];
            }
            else
            {
                if ([old isKindOfClass: [NSMutableArray class]])
                {
                    [(NSMutableArray*)old addObject: type];
                }
                else
                {
                    [Types setObject: [NSMutableArray arrayWithObjects: old, type, nil]
                              forKey: name];
                }
            }
		}
	}
	
	if (classes)
	{
		free(classes);
	}
}
+ (id) module
{
	return [[self alloc] init];
}
- (id) init
{
    self = [super init];
    if (self) {
        classes = [[NSMutableArray alloc] init];
        categories = [[NSMutableArray alloc] init];
        pragmas = [[NSMutableDictionary alloc] init];
    }
	return self;
}
- (void) addPragmas: (NSDictionary*)aDict
{
	NSEnumerator *e = [aDict keyEnumerator];
	for (id key = [e nextObject] ; nil != key ; key = [e nextObject])
	{
        id value = [NSPropertyListSerialization propertyListWithData: [[aDict objectForKey:key] dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:NSPropertyListMutableContainersAndLeaves
                                                              format:NULL
                                                               error:NULL];
		id oldValue = [pragmas objectForKey: key];
		if (nil == oldValue)
		{
			[pragmas setObject: value forKey: key];
		}
		else
		{
			NSAssert(NO, @"Code for merging pragmas not yet implemented");
		}
	}
}
- (void) addClass:(LKSubclass*)aClass
{
	[classes addObject:aClass];
}
- (void) addCategory:(LKCategory*)aCategory
{
	[categories addObject:aCategory];
}
- (BOOL)isSelectorPolymorphic: (NSString*)methodName
{
	return ([typeOverrides objectForKey: methodName] == nil)
		&&
		(nil != [SelectorConflicts objectForKey:methodName]);
}
- (NSArray*) typesForMethod:(NSString*)methodName
{
	NSString *type = [typeOverrides objectForKey: methodName];
	if (nil != type)
	{
		return [NSArray arrayWithObject:type];
	}
	NSArray *types = TypesForMethodName(methodName);
	
	if ([types count] == 0)
	{
		int argCount = 0;
		for (unsigned i=0, len = [methodName length] ; i<len ; i++)
		{
			if ([methodName characterAtIndex:i] == ':')
			{
				argCount++;
			}
		}
		int offset = sizeof(id) + sizeof(SEL);
        NSMutableString *ty = [NSMutableString stringWithFormat: @"%s%lu@0:%d",
			@encode(NSObject *), sizeof(SEL) + sizeof(id) * (argCount + 2),
			offset];
		for (int i=0 ; i<argCount ; i++)
		{
			offset += sizeof(id);
			[ty appendFormat: @"%s%d", @encode(NSObject *), offset];
		}
		types = [NSArray arrayWithObject: ty];
	}
	return types;
}
- (BOOL)check
{
	// We might want to get some from other sources in future and merge these.
	typeOverrides = [pragmas objectForKey:@"types"];
	BOOL success = YES;
	for (NSString *header in [pragmas objectForKey: @"headers"])
	{
		if (![LKCompiler loadHeader: header])
		{
            NSDictionary *errorDetails = nil;
            errorDetails = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSString stringWithFormat: @"Unable to load header: %@", header], kLKHumanReadableDescription,
                            header, kLKHeaderName,
                            self, kLKASTNode,
                            nil];
			success &= [LKCompiler reportWarning: LKMissingHeaderWarning
			                             details: errorDetails];
		}
	}
	for (LKSubclass *forwardClass in classes)
	{
		[LKSymbolTable symbolTableForClass: [forwardClass classname]];
	}
	for (LKAST *class in classes)
	{
		[class setParent:self];
		success &= [class check];
	}
	for (LKAST *category in categories)
	{
		[category setParent:self];
		success &= [category check];
	}
	return success;
}
- (NSString*) description
{
	NSMutableString *str = [NSMutableString string];
	for (LKAST *class in classes)
	{
		[str appendString:[class description]];
	}
	for (LKAST *category in categories)
	{
		[str appendString:[category description]];
	}
	return str;
}
- (void*) compileWithGenerator: (id<LKCodeGenerator>)aGenerator
{
	// FIXME: Get the file name from somewhere.
	[aGenerator startModule: @"Anonymous"];
    for (LKAST *class in classes)
	{
		[class compileWithGenerator: aGenerator];
	}
    for (LKAST *category in categories)
	{
		[category compileWithGenerator: aGenerator];
	}
	[aGenerator endModule];
	[[NSNotificationCenter defaultCenter]
	  	postNotificationName: LKCompilerDidCompileNewClassesNotification
		              object: nil];
	return NULL;
}
- (void) visitWithVisitor:(id<LKASTVisitor>)aVisitor
{
	[self visitArray: classes withVisitor: aVisitor];
	[self visitArray: categories withVisitor: aVisitor];
}
- (NSArray*)allClasses
{
	return classes;
}
- (NSArray*)allCategories
{
	return categories;
}
- (NSDictionary*) pragmas
{
	return pragmas;
}
@end
