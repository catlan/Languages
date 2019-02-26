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
     * this is not (yet) great. Find out whether the node can be executed, and
     * if so call the method that it supports for execution. Ideally, replace
     * those calls with a standard entry point, so that any AST can be executed
     * as a "do it" instruction, and this mess of inheritance testing can be
     * replaced with dynamic dispatch.
     *
     * And move the -execute… categories out of the interpreter context to here.
     */
    if ([_rootNode isKindOfClass:[LKBlockExpr class]]) {
        _returnValue = [(LKBlockExpr *)_rootNode executeBlock:receiver
                                                WithArguments:arguments
                                                        count:count
                                                    inContext:context];
    } else if ([_rootNode isKindOfClass:[LKMethod class]]) {
        LKMethod *method = (LKMethod *)_rootNode;
        NSMutableArray *symbolnames = [NSMutableArray array];
        LKMessageSend *signature = [method signature];
        if ([signature arguments])
        {
            [symbolnames addObjectsFromArray: [signature arguments]];
        }
        LKSymbolTable *symbols = [method symbols];
        [symbolnames addObjectsFromArray: [symbols locals]];
        
        LKInterpreterContext *context = [[LKInterpreterContext alloc]
                                         initWithSymbolTable: symbols
                                         parent: nil];
        [context setSelfObject: receiver];
        for (unsigned int i=0; i<count; i++)
        {
            LKVariableDecl *decl = [[signature arguments] objectAtIndex: i];
            [context setValue: arguments[i]
                    forSymbol: [decl name]];
        }
        _returnValue = [method executeWithReceiver:receiver
                                         arguments:arguments
                                             count:count
                                         inContext:context];
    } else {
        NSAssert(NO, @"I can't execute something that isn't a method or a block");
    }
}

- (id)returnValue
{
    return _returnValue;
}

@end
