//
//  LKDebuggerService.m
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>
#import "LKAST.h"
#import "LKCategory.h"
#import "LKContinueMode.h"
#import "LKDebuggerMode.h"
#import "LKDebuggerService.h"
#import "LKInterpreter.h"
#import "LKInterpreterContext.h"
#import "LKInterpreterRuntime.h"
#import "LKLineBreakpointDescription.h"
#import "LKMessageSend.h"
#import "LKMethod.h"
#import "LKSubclass.h"
#import "LKSymbolTable.h"
#import "LKVariableDescription.h"

@interface LKDebuggerService ()

- (NSString *)interpretedCallstackSymbol;

@end

@implementation LKDebuggerService
{
    LKAST *_currentNode;
    LKInterpreter *_interpreter;
    NSMutableSet<LKAST *> *_breakpointNodes;
    NSMutableSet<LKLineBreakpointDescription *> *_breakpointLines;
}

@synthesize mode = _mode;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mode = [LKContinueMode new];
        _mode.service = self;
        _breakpointNodes = [NSMutableSet set];
        _breakpointLines = [NSMutableSet set];
        _shouldStop = YES;
    }
    return self;
}

- (void)onTracepoint: (LKAST *)aNode
{
    _currentNode = aNode;
    // assertion: this sets interpreter correctly, because we're interpreting on this thread.
    _interpreter = [LKInterpreter interpreter];
    [_mode onTracepoint:aNode];
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

- (void)activate
{
    [LKInterpreter setActiveDebugger:self];
}

- (void)deactivate
{
    [LKInterpreter setActiveDebugger:nil];
}

- (NSSet <LKVariableDescription *>*)allVariables
{
    LKInterpreterContext *context = [_interpreter topContext];
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

- (NSArray<NSString *> *)stacktrace
{
    NSArray <NSString *>* callSymbols = [self.mode stacktrace];
    
    // filter out our own methods, so you only see yours
    NSPredicate *noLanguageKitMethods = [NSPredicate predicateWithBlock:^BOOL(NSString * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return !([evaluatedObject containsString:@"LanguageKit"] ||
                 [evaluatedObject containsString:@"libffi_Mac.dylib"]);
    }];
    callSymbols = [callSymbols filteredArrayUsingPredicate:noLanguageKitMethods];
    
    return [@[[self interpretedCallstackSymbol]] arrayByAddingObjectsFromArray:callSymbols];
}

- (void)addBreakpoint:(LKAST *)breakAtNode
{
    [_breakpointNodes addObject:breakAtNode];
}

- (void)removeBreakpoint:(LKAST *)breakpoint
{
    NSParameterAssert([self hasBreakpointAt:breakpoint]);
    [_breakpointNodes removeObject:breakpoint];
}

- (void)addLineBreakpoint:(LKLineBreakpointDescription *)breakpoint
{
    [_breakpointLines addObject:breakpoint];
}

- (void)removeLineBreakpoint:(LKLineBreakpointDescription *)breakpoint
{
    [_breakpointLines removeObject:breakpoint];
}

- (BOOL)hasBreakpointAt:(LKAST *)aNode
{
    return [_breakpointNodes containsObject:aNode];
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

- (NSString *)interpretedCallstackSymbol
{
    NSString *className = nil, *methodName = nil, *categoryName = nil, *prefix = nil;
    LKAST *node = _currentNode;
    do {
        if ([node isKindOfClass:[LKMethod class]]) {
            LKMethod *method = (LKMethod *)node;
            methodName = method.signature.selector;
            prefix = [method isClassMethod] ? @"+" : @"-";
        }
        if ([node isKindOfClass:[LKCategoryDef class]]) {
            LKCategoryDef *category = (LKCategoryDef *)node;
            categoryName = [category categoryName];
            className = [category classname];
        }
        if ([node isKindOfClass:[LKSubclass class]]) {
            LKSubclass *subclass = (LKSubclass *)node;
            className = [subclass classname];
        }
        node = [node parent];
    } while (node != nil);
    
    // the duplicate logic here is because compilers don't like non-literal format strings
    if (categoryName) {
        return [NSString stringWithFormat:@"<Interpreted>        %@[%@(%@) %@]",
                prefix,
                className,
                categoryName,
                methodName];
    } else {
        return [NSString stringWithFormat:@"<Interpreted>        %@[%@ %@]",
                prefix,
                className,
                methodName];
    }
}
@end
