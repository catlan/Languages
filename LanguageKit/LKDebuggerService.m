//
//  LKDebuggerService.m
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>
#import "LKAST.h"
#import "LKDebuggerMode.h"
#import "LKDebuggerService.h"
#import "LKInterpreter.h"
#import "LKInterpreterRuntime.h"
#import "LKSymbolTable.h"
#import "LKVariableDescription.h"

@implementation LKDebuggerService
{
    LKAST *_currentNode;
    id <LKDebuggerMode> _currentMode;
    LKInterpreterContext *_currentContext;
}

- (void)onTracepoint: (LKAST *)aNode inContext: (LKInterpreterContext *)context
{
    _currentNode = aNode;
    [_currentMode onTracepoint:aNode];
    _currentContext = context;
}

- (LKAST *)currentNode
{
    return _currentNode;
}

- (void)setMode:(id<LKDebuggerMode>)aMode
{
    _currentMode = aMode;
    _currentMode.service = self;
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
    // TODO: do I need to do anything extra for block context objects?
    // don't recurse for self or block context, because they're inherited
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
@end
