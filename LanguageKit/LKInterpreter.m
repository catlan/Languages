#import "Runtime/BigInt.h"
#import "Runtime/BoxedFloat.h"
#import "Runtime/Symbol.h"
#import "LanguageKit/LanguageKit.h"
#import "LKInterpreter.h"
#import "LKInterpreterRuntime.h"

#include <math.h>
#include <dlfcn.h>

NSString *LKInterpreterException = @"LKInterpreterException";

static NSMutableDictionary *LKClassVariables;
static NSMutableDictionary *LKMethodASTs;

LKMethod *LKASTForMethod(Class cls, NSString *selectorName)
{
	BOOL isClassMethod = class_isMetaClass(cls);
	LKMethod *ast = nil;
	do
	{
		ast = [LKMethodASTs valueForKey:
			[NSString stringWithFormat: @"%s%c%@", 
				class_getName(cls), isClassMethod ? '+' : '-', selectorName]];
		cls = class_getSuperclass(cls);
	} while (ast == nil && cls != nil);
	return ast;
}

static void StoreASTForMethod(NSString *classname, BOOL isClassMethod,
                              NSString *selectorName, LKMethod *method)
{
	[LKMethodASTs setValue: method
	                forKey: [NSString stringWithFormat: @"%@%@%@", 
	                                         classname,
                                                 isClassMethod ? @"+" : @"-",
	                                         selectorName]];
}

OBJC_EXPORT id objc_retain(id value);
OBJC_EXPORT id objc_retainAutorelease(id value);
OBJC_EXPORT id objc_retainAutoreleaseReturnValue(id obj);

id LKPropertyGetter(id self, SEL _cmd)
{
    return objc_retainAutoreleaseReturnValue(objc_getAssociatedObject(self, _cmd)); // objc_retainAutoreleaseReturnValue() ?
}

void LKPropertySetter(id self, SEL _cmd, id newObject)
{
    NSString *setterString = NSStringFromSelector(_cmd);
    if (![setterString hasPrefix:@"set"])
    {
        NSLog(@"LKPropertySetter warning property setter should start with 'set', %@", setterString);
    }
    NSString *getterString = ({
        NSString *str = [setterString substringFromIndex:3];
        NSString *firstCharacter = [[str substringToIndex:1]  lowercaseString];
        str = [firstCharacter stringByAppendingString:[str substringFromIndex:1]];
        str = [str substringToIndex:[str length]-1];
        str;
    });
    SEL getterSelector = NSSelectorFromString(getterString);
    
    id oldObject =  objc_getAssociatedObject(self, getterSelector);
    if (oldObject != newObject)
    {
        objc_setAssociatedObject(self, getterSelector, newObject, OBJC_ASSOCIATION_RETAIN);
    }
}

@interface LKBlockReturnException : NSException
{
}
+ (void)raiseWithValue: (id)returnValue;
- (id)returnValue;
@end
@implementation LKBlockReturnException
+ (void)raiseWithValue: (id)returnValue
{
	@throw [LKBlockReturnException exceptionWithName: LKSmalltalkBlockNonLocalReturnException
	                                    reason: @""
	                                  userInfo: [NSDictionary dictionaryWithObjectsAndKeys:returnValue, @"returnValue", nil]];
}
- (id)returnValue
{
	return [[self userInfo] valueForKey: @"returnValue"];
}
@end

@implementation LKInterpreterContext
@synthesize selfObject, blockContextObject;
- (id) initWithSymbolTable: (LKSymbolTable*)aTable
                    parent: (LKInterpreterContext*)aParent
{
    self = [super init];
    if (self) {
        parent = aParent;
        symbolTable = aTable;
        selfObject = [aParent selfObject];
        blockContextObject = [aParent blockContextObject];
        objects = [NSMutableDictionary new];
    }
	return self;
}
- (LKInterpreterContext *) parent
{
	return parent;
}
- (LKSymbolTable *) symbolTable
{
	return symbolTable;
}
- (void) setValue: (id)value forSymbol: (NSString*)symbol
{
    if (value)
    {
        [objects setObject: value forKey: symbol];
    }
}
- (id) valueForSymbol: (NSString*)symbol
{
	return [objects objectForKey: symbol];
}
- (LKInterpreterVariableContext)contextForSymbol: (LKSymbol*)symbol
{
	LKInterpreterVariableContext context;
	context.context = self;
	context.scope = [[symbolTable symbolForName: [symbol name]] scope];
	if (context.scope == LKSymbolScopeExternal)
	{
		return [parent contextForSymbol: symbol];
	}
	return context;
}
- (void)onTracepoint:(LKAST *)aNode
{
    
}
@end


@implementation LKAST (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
    [NSException raise: NSInvalidArgumentException
                format: @"-[%@ %@] should be overridden by subclass", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	return nil;
}
@end

@interface LKArrayExpr (LKInterpreter)
@end
@implementation LKArrayExpr (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	unsigned int count = [elements count];
	id interpretedElements[count];
	for (unsigned int i=0; i<count; i++)
	{
		[elements objectAtIndex: i];
		interpretedElements[i] =
			[(LKAST*)[elements objectAtIndex: i] interpretInContext: context];
		[elements objectAtIndex: i];
	}
    [context onTracepoint:self];
    
	return [NSMutableArray arrayWithObjects: interpretedElements count: count];
}
@end

@interface LKAssignExpr (LKInterpreter)
@end
@implementation LKAssignExpr (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)currentContext
{
	id rvalue = [expr interpretInContext: currentContext];

	LKInterpreterVariableContext context = [currentContext contextForSymbol: [target symbol]];

	NSString *symbolName = [[target symbol] name];
	switch (context.scope)
	{
		case LKSymbolScopeLocal:
		{
			[context.context setValue: rvalue
			                forSymbol: symbolName];
			break;
		}
		case LKSymbolScopeObject:
		{
			LKSetIvar([context.context selfObject], symbolName, rvalue);
			break;
		}
		case LKSymbolScopeClass:
		{
			LKAST *p = [self parent];
			while (NO == [p isKindOfClass: [LKSubclass class]] && nil != p)
			{
				p = [p parent];
			}
			[(LKSubclass*)p setValue: rvalue forClassVariable: symbolName];
			break;
		}
		default:
			NSAssert1(NO, @"Don't know how to assign to %@", symbolName);
			break;
	}
	return rvalue;
}
@end

@implementation LKBlockExpr (LKInterpreter)
- (id)executeBlock: (id)block
     WithArguments: (const id*)args
             count: (int)count
         inContext: (LKInterpreterContext*)context
{
	NSArray *arguments = [[self symbols] arguments];
	for (int i=0; i<count; i++)
	{
		[context setValue: args[i]
		        forSymbol: [[arguments objectAtIndex: i] name]];
	} 
	[context setBlockContextObject: block];

	id result = nil;
	for (LKAST *statement in statements)
	{
		result = [statement interpretInContext: context];
	}
	[context setBlockContextObject: nil];
	return result;
}
- (id)interpretInContext: (LKInterpreterContext*)parentContext
{
	int count = [[[self symbols] arguments] count];
	id (^block)(__unsafe_unretained id arg0, ...) = ^id(__unsafe_unretained id arg0, ...) {
		LKInterpreterContext *context = [[LKInterpreterContext alloc]
		            initWithSymbolTable: [self symbols]
		                         parent: parentContext];
		id params[count];
		
		va_list arglist;
		va_start(arglist, arg0);
		if (count > 0)
		{
			params[0] = arg0;
		}
		for (int i = 1; i < count; i++)
		{
			params[i] = (id) va_arg(arglist, __unsafe_unretained id);
		}
		va_end(arglist);
		
		@try
		{
			return [self executeBlock: self
			            WithArguments: params
			                    count: count
			                inContext: context];
		}
		@finally
		{
			context = nil;
		}
		return nil;
	};
	return [block copy];
}
@end

@interface LKCategoryDef (LKInterpreter)
@end
@implementation LKCategoryDef (LKInterpreter)

+ (void)initialize
{
    if (self == [LKCategoryDef class])
    {
        LKMethodASTs = [[NSMutableDictionary alloc] init];
    }
}

- (id)interpretInContext: (LKInterpreterContext*)context
{
	Class cls = NSClassFromString(classname);
	if (cls == Nil)
	{
		[NSException raise: LKInterpreterException
		            format: @"Tried to create category %@ on non-existing class %@",
		                    categoryName, classname];
	}
	for (LKMethod *method in methods)
	{
		BOOL isClassMethod = [method isKindOfClass: [LKClassMethod class]];
		NSString *methodName = [[method signature] selector];
		SEL sel = NSSelectorFromString(methodName);
		//FIXME: check the superclass type explicitly
		const char *type = [[[(LKModule*)[self parent] typesForMethod: methodName] objectAtIndex: 0] UTF8String];
		Class destClass = isClassMethod ? object_getClass(cls) : cls;
		class_replaceMethod(destClass, sel, LKInterpreterMakeIMP(destClass, type), type);
		StoreASTForMethod(classname, isClassMethod, methodName, method);
	}
	return nil;
}
@end


@interface LKComment (LKInterpreter)
@end
@implementation LKComment (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	return nil;
}
@end

@interface LKCompare (LKInterpreter)
@end
@implementation LKCompare (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	id lhsInterpreted = [lhs interpretInContext: context];
	
	id rhsInterpreted = [rhs interpretInContext: context];

    [context onTracepoint: self];
	return [BigInt bigIntWithLong: lhsInterpreted == rhsInterpreted];
}
@end

@interface LKDeclRef (LKInterpreter)
@end
@implementation LKDeclRef (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)currentContext
{
	LKSymbol *symbol = [self symbol];
	LKInterpreterVariableContext context = [currentContext contextForSymbol: symbol];
	NSString *symbolName = [symbol name];
	switch (context.scope)
	{
		case LKSymbolScopeObject:
		{
			return LKGetIvar([currentContext selfObject], symbolName); 
		}
		case LKSymbolScopeLocal:
		case LKSymbolScopeArgument:
		{
			return [context.context valueForSymbol: symbolName];
		}
		case LKSymbolScopeGlobal:
			return NSClassFromString(symbolName);
		case LKSymbolScopeClass:
		{
			LKAST *p = [self parent];
			while (NO == [p isKindOfClass: [LKSubclass class]] && nil != p)
			{
				p = [p parent];
			}
			return [(LKSubclass*)p valueForClassVariable: symbolName];
		}
		default:
			break;
	}
	NSAssert(NO, @"Can't interpret decl ref");
	return nil;
}
@end
@implementation LKNilRef (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)currentContext
{
	return nil;
}
@end
@implementation LKSelfRef (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)currentContext
{
	return [currentContext selfObject];
}
@end
@implementation LKSuperRef (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)currentContext
{
	return [currentContext selfObject];
}
@end
@implementation LKBlockSelfRef (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)currentContext
{
	return [currentContext blockContextObject];
}
@end

@interface LKIfStatement (LKInterpreter)
@end
@implementation LKIfStatement (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	id result = nil;
	NSArray *statements = [[condition interpretInContext: context] boolValue] ?
		thenStatements : elseStatements;
    for (LKAST *statement in statements)
	{
		result = [statement interpretInContext: context];
	}
    [context onTracepoint: self];
	return result;
}
@end

@interface LKStringLiteral (LKInterpreter)
@end
@implementation LKStringLiteral (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
    [context onTracepoint: self];
	return value;
}
@end

@interface LKNumberLiteral (LKInterpreter)
@end
@implementation LKNumberLiteral (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
    [context onTracepoint: self];
	return [BigInt bigIntWithCString: [value UTF8String]];
}
@end

@interface LKFloatLiteral (LKInterpreter)
@end
@implementation LKFloatLiteral (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
    [context onTracepoint: self];
	return [BoxedFloat boxedFloatWithCString: [value UTF8String]];
}
@end

@interface LKFunctionCall (LKInterpreter)
@end
@implementation LKFunctionCall (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	NSArray *arguments = [self arguments];
	unsigned int argc = [arguments count];
	id argv[argc];
	for (unsigned int i=0 ; i<argc ; i++)
	{
		LKAST *arg = [arguments objectAtIndex: i];
		@try
		{
			argv[i] = [arg interpretInContext: context];
		}
		@finally
		{
			arg = nil;
		}
	}
	return LKCallFunction([self functionName], [self typeEncoding], argc, argv);
}
@end

@interface LKMessageSend (LKInterpreter)
@end
@implementation LKMessageSend (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context forTarget: (id)receiver
{
    if ([selector isEqual: @"ifNil:"])
    {
        if (!receiver)
        {
            id block = [[arguments firstObject] interpretInContext: context];
            [context onTracepoint: self];
            return LKSendMessage(@"NSBlock", block, @"value", 0, NULL);
        }
    }
    else if ([selector isEqual: @"ifNotNil:"])
    {
        if (receiver)
        {
            id block = [[arguments firstObject] interpretInContext: context];
            [context onTracepoint: self];
            return LKSendMessage(@"NSBlock", block, @"value", 0, NULL);
        }
    }
    else if ([selector isEqual: @"ifNil:ifNotNil:"])
    {
        id argument = (!receiver) ? [arguments firstObject] : [arguments lastObject];
        id block = [argument interpretInContext: context];
        [context onTracepoint: self];
        return LKSendMessage(@"NSBlock", block, @"value", 0, NULL);
    }
    else if ([selector isEqual: @"ifNotNil:ifNil:"])
    {
        id argument = (receiver) ? [arguments firstObject] : [arguments lastObject];
        id block = [argument interpretInContext: context];
        [context onTracepoint: self];
        return LKSendMessage(@"NSBlock", block, @"value", 0, NULL);
    }
	NSString *receiverClassName = nil;
	if ([target isKindOfClass: [LKSuperRef class]])
	{
		LKAST *ast = [self parent];
		while (nil != ast && ![ast isKindOfClass: [LKSubclass class]])
		{
			ast = [ast parent];
		}
		receiverClassName = [(LKSubclass*)ast superclassname];
	}
	unsigned int argc = [arguments count];
	__strong id argv[argc];
	for (unsigned int i=0 ; i<argc ; i++)
	{
		LKAST *arg = [arguments objectAtIndex: i];
		@try
		{
			argv[i] = [arg interpretInContext: context];
		}
		@finally
		{
			arg = nil;
		}
	}
    [context onTracepoint: self];
	return LKSendMessage(receiverClassName, receiver, selector, argc, argv);
}
- (id)interpretInContext: (LKInterpreterContext*)context
{
	id result = [self interpretInContext: context
	                      forTarget: [(LKAST*)target interpretInContext: context]];
	return result;
}
@end


@interface LKMessageCascade (LKInterpreter)
@end
@implementation LKMessageCascade (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	id result = nil;
	id target = [receiver interpretInContext: context];
	for (LKMessageSend *message in messages)
	{
		result = [message interpretInContext: context forTarget: target];
	}
	return result;
}
@end

@implementation LKMethod (LKInterpreter)
- (id)executeInContext: (LKInterpreterContext*)context
{
	id result = nil;
	@try
	{
		for (LKAST *element in [self statements])
		{
			result = [element interpretInContext: context];
		}
		if ([[[self signature] selector] isEqualToString: @"dealloc"])
		{
			LKAST *ast = [self parent];
			while (nil != ast && ![ast isKindOfClass: [LKSubclass class]])
			{
				ast = [ast parent];
			}
			NSString *receiverClassName = [(LKSubclass*)ast superclassname];
			return LKSendMessage(receiverClassName, [context selfObject], @"dealloc", 0, 0);
		}
	}
	@catch (LKBlockReturnException *ret)
	{
		result = [ret returnValue];
	}
	return result;
}
- (id)executeWithReciever: (id)receiver arguments: (const id*)args count: (int)count
{
	NSMutableArray *symbolnames = [NSMutableArray array];
	LKMessageSend *signature = [self signature];
	if ([signature arguments])
	{
		[symbolnames addObjectsFromArray: [signature arguments]];
	}
	[symbolnames addObjectsFromArray: [symbols locals]];
	
	LKInterpreterContext *context = [[LKInterpreterContext alloc]
							initWithSymbolTable: symbols
							             parent: nil];
	[context setSelfObject: receiver];
	for (unsigned int i=0; i<count; i++)
	{
        LKVariableDecl *decl = [[signature arguments] objectAtIndex: i];
		[context setValue: args[i]
		        forSymbol: [decl name]];
	}

	id result = nil;
	@try
	{
		result = [self executeInContext: context];
	}
	@finally
	{
		context = nil;
	}

	return result;
}
@end


@interface LKModule (LKInterpreter)
@end
@implementation LKModule (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	for (LKAST *class in classes)
	{
		[class interpretInContext: context];
	}
	for (LKAST *category in categories)
	{
		[category interpretInContext: context];
	}
	return nil;
}
@end


@interface LKBlockReturn (LKInterpreter)
@end
@implementation LKBlockReturn (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	id value = [ret interpretInContext: context];
	return value;
}
@end


@interface LKReturn (LKInterpreter)
@end
@implementation LKReturn (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	id value = [ret interpretInContext: context];
    [context onTracepoint:self];
    return value;
	//[LKBlockReturnException raiseWithValue: value];
	//return nil;
}
@end


@implementation LKSubclass (LKInterpreter)

+ (void)initialize
{
	if (self == [LKSubclass class])
	{
		LKMethodASTs = [[NSMutableDictionary alloc] init];
		LKClassVariables = [[NSMutableDictionary alloc] init];
	}
}

- (void)setValue: (id)value forClassVariable: (NSString*)cvar
{
	if (nil == [LKClassVariables valueForKey: [self classname]])
	{
		[LKClassVariables setValue: [NSMutableDictionary dictionary]
		                    forKey: [self classname]];
	}
	[[LKClassVariables valueForKey: [self classname]] setValue: value
	                                                    forKey: cvar];
}

- (id)valueForClassVariable: (NSString*)cvar
{
	return [[LKClassVariables valueForKey: [self classname]] valueForKey: cvar];
}

static uint8_t logBase2(uint8_t x)
{
	uint8_t result = 0;
	while (x > 1)
	{
		result++;
		x = x >> 1;
	}
	return result;
}

- (id)interpretInContext: (LKInterpreterContext*)context
{
	// Make sure the superclass is interpreted first
	Class supercls = NSClassFromString(superclass);
	if (Nil == supercls)
	{
		for (LKSubclass *class in [(LKModule*)[self parent] allClasses])
		{
			if ([[class classname] isEqualToString: superclass])
			{
				supercls = [class interpretInContext: context];
				break;
			}
		}
		if (Nil == supercls)
		{
			[NSException raise: LKInterpreterException
						format: @"Superclass %@ (of class %@) not found",
			                    superclass, classname];
		}
	}
	
	Class cls = NSClassFromString(classname);
	BOOL alreadyExists = (Nil != cls);
	if (!alreadyExists)
	{
		cls = objc_allocateClassPair(supercls, [classname UTF8String], 0);
	}
	else
	{
		NSLog(@"LKInterpreter: class %@ is already defined", cls);
	}

	for (LKVariableDecl *ivar in ivars)
	{
		class_addIvar(cls, [[ivar name] UTF8String], sizeof(id), logBase2(__alignof__(id)), "@");
	}

    for (LKProperty *property in properties)
    {
        NSString *propertyName = [property name];
        NSString *propertyBackingIVar = [@"_" stringByAppendingString:propertyName];
        //class_addIvar(cls, [ivar UTF8String], sizeof(id), logBase2(__alignof__(id)), "@");
        objc_property_attribute_t type = { "T", "@\"NSObject\"" };
        objc_property_attribute_t ownership = { "R", "" }; // C = copy
        objc_property_attribute_t backingivar  = { "V", [propertyBackingIVar UTF8String] };
        objc_property_attribute_t attrs[] = { type, ownership, backingivar };
        class_addProperty(cls, [propertyName UTF8String], attrs, 3);
        
        NSString *setterString = [[[propertyName substringToIndex:1] uppercaseString] stringByAppendingString:[propertyName substringFromIndex:1]];
        setterString = [[@"set" stringByAppendingString:setterString] stringByAppendingString:@":"];
        
        
        class_addMethod(cls, NSSelectorFromString(propertyName), (IMP)LKPropertyGetter, "@@:");
        class_addMethod(cls, NSSelectorFromString(setterString), (IMP)LKPropertySetter, "v@:@");
        
    }
    
	for (LKMethod *method in methods)
	{
		BOOL isClassMethod = [method isKindOfClass: [LKClassMethod class]];
		NSString *methodName = [[method signature] selector];
		SEL sel = NSSelectorFromString(methodName);
		//FIXME: If overriding, check the superclass type explicitly
		const char *type = [[[(LKModule*)[self parent] typesForMethod: methodName] objectAtIndex: 0] UTF8String];
		Class destClass = isClassMethod ? object_getClass(cls) : cls;
        if (alreadyExists)
        {
            class_replaceMethod(destClass, sel, LKInterpreterMakeIMP(destClass, type), type);
        }
        else
        {
            class_addMethod(destClass, sel, LKInterpreterMakeIMP(destClass, type), type);
        }
		StoreASTForMethod(classname, isClassMethod, methodName, method);
	}
	
	if (!alreadyExists)
	{
		objc_registerClassPair(cls);
		[cls load];
	}
    
    [context onTracepoint: self];
	return cls;
}
@end
@implementation LKVariableDecl (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	[context setValue: nil forSymbol: (NSString*)variableName];
    [context onTracepoint:self];
	return nil;
}
@end
@implementation LKLoop (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
	// FIXME: @try for LKBreak support.
	BOOL cond = YES;
	
	for (LKAST *statement in loopInitStatements)
	{
		[statement interpretInContext: context];
	}
	while (cond)
	{
		if (nil != preCondition)
		{
			cond = [[preCondition interpretInContext: context] boolValue];
			if (!cond) { break; }
		}
		for (LKAST *statement in statements)
		{
			[statement interpretInContext: context];
		}
		for (LKAST *statement in updateStatements)
		{
			[statement interpretInContext: context];
		}
		if (nil != postCondition)
		{
			cond = [[postCondition interpretInContext: context] boolValue];
		}
	}
    [context onTracepoint: self];
	return nil;
}
@end


@interface LKSymbolRef (LKInterpreter)
@end
@implementation LKSymbolRef (LKInterpreter)
- (id)interpretInContext: (LKInterpreterContext*)context
{
    id s = nil;//[Symbol SymbolForString: symbol];
    if (nil == s)
    {
        void ** dataPtr = dlsym(RTLD_DEFAULT, [symbol UTF8String]);
        s = (__bridge NSString *)(dataPtr ? *dataPtr : nil);
    }
    return s;
}
@end
