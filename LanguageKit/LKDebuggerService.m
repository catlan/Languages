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
}

- (void)onTracepoint: (LKAST *)aNode
{
    _currentNode = aNode;
    [_currentMode onTracepoint:aNode];
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
@end
