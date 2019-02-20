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
#import "LKSymbolTable.h"

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

- (NSArray <NSDictionary *>*)allVariables
{
    LKInterpreterContext *context = _currentContext;
    NSMutableArray *symbolTables = [NSMutableArray array];
    while(context != nil) {
        [symbolTables addObject:[context allVariables]];
        context = context->parent;
    }
    return [symbolTables copy];
}
@end
