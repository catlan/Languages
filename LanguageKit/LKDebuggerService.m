//
//  LKDebuggerService.m
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>
#import "LKAST.h"
#import "LKContinueMode.h"
#import "LKDebuggerMode.h"
#import "LKDebuggerService.h"
#import "LKInterpreter.h"
#import "LKInterpreterRuntime.h"
#import "LKSymbolTable.h"
#import "LKVariableDescription.h"

@interface LKDebuggerService ()

@property (atomic, strong, readwrite) NSThread *executingThread;

@end

@implementation LKDebuggerService
{
    LKAST *_currentNode;
    LKInterpreterContext *_currentContext;
    NSMutableSet<LKAST *> *_breakpoints;
}

@synthesize mode = _mode;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mode = [LKContinueMode new];
        _mode.service = self;
        _breakpoints = [NSMutableSet set];
        _shouldStop = YES;
    }
    return self;
}

- (void)onTracepoint: (LKAST *)aNode inContext: (LKInterpreterContext *)context
{
    self.executingThread = [NSThread currentThread];
    _currentNode = aNode;
    [_mode onTracepoint:aNode];
    _currentContext = context;
}

- (LKAST *)currentNode
{
    return _currentNode;
}

- (void)setMode:(id<LKDebuggerMode>)aMode
{
    _mode.service = nil;
    aMode.service = self;
    _mode = aMode;
}

- (void)debugScript:(LKAST *)rootNode
{
    LKSymbolTable *table = [LKSymbolTable new];
    [table setTableScope:LKSymbolScopeGlobal];
    LKInterpreterContext *context = [[LKInterpreterContext alloc] initWithSymbolTable:table parent:nil];
    context.debugger = self;
    [rootNode interpretInContext:context];
}

- (NSSet <LKVariableDescription *>*)allVariables
{
    LKInterpreterContext *context = _currentContext;
    NSMutableSet *variables = [NSMutableSet set];
    // don't recurse for self references, because they're inherited
    id selfObject = [context selfObject];
    if (selfObject) {
        // I don't use -[obj class] here in case that's implemented by the interpreter
        NSString *className = [NSString stringWithUTF8String:object_getClassName(selfObject)];
        LKSymbolTable *ivars = [LKSymbolTable
                                symbolTableForClass:className];
        // FIXME observation: the symbol table can't represent indexed ivars
        for (NSString *name in [ivars symbols]) {
            LKSymbol *symbol = [ivars symbolForName:name];
            /*
             * Workaround: isa for tagged pointers can't be looked up via LKGetIvar()
             * So in that specific case, just hand over the class.
             */
            id value = nil;
            if ([name isEqualToString:@"isa"]) {
                value = NSClassFromString(className);
            }
            else {
                value = LKGetIvar(selfObject, name);
            }
            LKVariableDescription *desc = [[LKVariableDescription alloc]
                                           initWithSymbol:symbol value:value];
            [variables addObject:desc];
        }
    }
    while(context != nil) {
        for (NSString *name in [context allVariables]) {
            id value = [context valueForSymbol:name];
            LKSymbol *symbol = [context->symbolTable symbolForName:name];
            if (symbol.scope == LKSymbolScopeExternal) {
                LKInterpreterVariableContext definingContext = [context contextForSymbol:symbol];
                symbol = [definingContext.context->symbolTable
                          symbolForName:name];
            }
            LKVariableDescription *desc = [[LKVariableDescription alloc]
                                           initWithSymbol:symbol
                                           value:value];
            [variables addObject:desc];
        }
        context = context->parent;
    }
    return [variables copy];
}

- (void)addBreakpoint:(LKAST *)breakAtNode
{
    [_breakpoints addObject:breakAtNode];
}

- (void)removeBreakpoint:(LKAST *)breakpoint
{
    NSParameterAssert([self hasBreakpointAt:breakpoint]);
    [_breakpoints removeObject:breakpoint];
}

- (BOOL)hasBreakpointAt:(LKAST *)aNode
{
    return [_breakpoints containsObject:aNode];
}

- (void)pause
{
    [_mode pause];
}

- (void)resume
{
    [_mode resume];
}

- (void)stepInto
{
    [_mode stepInto];
}

- (void)stepOut
{
    [_mode stepOut];
}

@end
