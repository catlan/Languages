//
//  LKInterpreter.m
//  LanguageKit
//
//  Created by Graham Lee on 26/02/2019.
//

#import "LKInterpreter.h"
#import "LKAST.h"
#import "LKBlockExpr.h"
#import "LKDebuggerService.h"
#import "LKInterpreterContext.h"
#import "LKInterpreterRuntime.h"
#import "LKMethod.h"
#import "LKVariableDecl.h"

static const NSString *LKInterpreterThreadKey = @"LKInterpreterThreadKey";

@implementation LKInterpreter
{
    NSMutableArray <LKInterpreterContext *> *_contexts;
    id _returnValue;
}

static LKDebuggerService *LKActiveDebugger;

+ (LKDebuggerService *)activeDebugger
{
    return LKActiveDebugger;
}
+ (void)setActiveDebugger:(LKDebuggerService *)aDebugger
{
    LKActiveDebugger = aDebugger;
}

+ (instancetype)interpreter
{
    LKInterpreter *threadInterpreter = [[NSThread currentThread] threadDictionary][LKInterpreterThreadKey];
    if (!threadInterpreter) {
        threadInterpreter = [self new];
        [[NSThread currentThread] threadDictionary][LKInterpreterThreadKey] = threadInterpreter;
    }
    return threadInterpreter;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _contexts = [NSMutableArray array];
    }
    return self;
}

- (void)executeCode:(LKAST *)rootNode
       withReceiver:(id)receiver
          arguments:(const __autoreleasing id *)arguments
              count:(int)count
{
    BOOL needsNewContext = ![rootNode inheritsContext];
    if (needsNewContext) {
        LKInterpreterContext *nextContext = [rootNode freshContextWithReceiver:receiver
                                                                     arguments:arguments
                                                                         count:count];
        [self pushContext:nextContext];
    }
    _returnValue = [rootNode executeWithReceiver:receiver
                                            args:arguments
                                           count:count
                                       inContext:[self topContext]];
    if (needsNewContext) {
        [self popContext];
    }
}

- (id)returnValue
{
    return _returnValue;
}

- (void)pushContext:(LKInterpreterContext *)aContext
{
    [aContext setInterpreter:self];
    [_contexts insertObject:aContext atIndex:0];
}

- (void)popContext
{
    [[self topContext] setInterpreter:nil];
    [_contexts removeObjectAtIndex:0];
}

- (LKInterpreterContext *)topContext
{
    return _contexts[0];
}

- (void)onTracepoint:(LKAST *)aNode
{
    [[[self class] activeDebugger] onTracepoint:aNode inContext:[self topContext]];
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

- (BOOL)inheritsContext
{
    return NO;
}

- (LKInterpreterContext *)freshContextWithReceiver: (id)receiver
                                         arguments: (const __autoreleasing id *)arguments
                                             count: (int)count
{
    NSMutableArray *symbolnames = [NSMutableArray array];
    LKMessageSend *signature = [self signature];
    if ([signature arguments])
    {
        [symbolnames addObjectsFromArray: [signature arguments]];
    }
    LKSymbolTable *symbols = [self symbols];
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
    return nextContext;
}

@end

@implementation LKBlockExpr (Executing)

- (id)executeWithReceiver:(id)block
                     args:(const __autoreleasing id *)args
                    count:(int)count
                inContext:(LKInterpreterContext *)context
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
