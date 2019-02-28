//
//  LKInterpreter.m
//  LanguageKit
//
//  Created by Graham Lee on 26/02/2019.
//

#import "LKInterpreter.h"
#import "LKAST.h"
#import "LKBlockExpr.h"
#import "LKInterpreterContext.h"
#import "LKInterpreterRuntime.h"
#import "LKMethod.h"
#import "LKVariableDecl.h"

@interface LKInterpreter ()

- (instancetype)initWithRootNode:(LKAST *)root;

@end

@implementation LKInterpreter
{
    LKAST *_rootNode;
    id _returnValue;
}

+ (instancetype)interpreterForCode:(LKAST *)root
{
    return [[self alloc] initWithRootNode:root];
}

- (instancetype)initWithRootNode:(LKAST *)root
{
    self = [super init];
    if (self) {
        _rootNode = root;
    }
    return self;
}

- (void)executeWithReceiver:(id)receiver
                  arguments:(const __autoreleasing id *)arguments
                      count:(int)count
                  inContext:(LKInterpreterContext *)context
{
    /*
     * this is not (yet) great. Find out whether I have a context already. If so,
     * and the root node is of a type that should inherit an existing context, just
     * execute it. If not, create a new context, keep a reference to it here, and
     * execute in that context. The context parameter up there should disappear, and
     * this object should know what context to use.
     */
    if ([_rootNode isKindOfClass:[LKMethod class]]) {
        LKMethod *method = (LKMethod *)_rootNode;
        NSMutableArray *symbolnames = [NSMutableArray array];
        LKMessageSend *signature = [method signature];
        if ([signature arguments])
        {
            [symbolnames addObjectsFromArray: [signature arguments]];
        }
        LKSymbolTable *symbols = [method symbols];
        [symbolnames addObjectsFromArray: [symbols locals]];
        
        LKInterpreterContext *nextContext = [[LKInterpreterContext alloc]
                                         initWithSymbolTable: symbols
                                         parent: nil];
        [nextContext setSelfObject: receiver];
        for (unsigned int i=0; i<count; i++)
        {
            LKVariableDecl *decl = [[signature arguments] objectAtIndex: i];
            [nextContext setValue: arguments[i]
                    forSymbol: [decl name]];
        }
        // TODO push context onto a stack
        context = nextContext;
    }
    _returnValue = [_rootNode executeWithReceiver:receiver
                                             args:arguments
                                            count:count
                                        inContext:context];
    // TODO now pop the context again, if I made a new one
}

- (id)returnValue
{
    return _returnValue;
}

@end

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

@implementation LKMethod (Executing)
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
- (id)executeWithReceiver: (id)receiver
                     args: (const id*)args
                    count: (int)count
                inContext: (LKInterpreterContext *)context
{
    return [self executeInContext: context];
}

@end

@implementation LKBlockExpr (Executing)

- (id)executeWithReceiver:(id)block args:(const __autoreleasing id *)args count:(int)count inContext:(LKInterpreterContext *)context
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

@end
