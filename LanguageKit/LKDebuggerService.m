//
//  LKDebuggerService.m
//  LanguageKit
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>
#import "LKAST.h"
#import "LKDebuggerService.h"

@implementation LKDebuggerService
{
    LKAST *_currentNode;
}

- (void)onTracepoint: (LKAST *)aNode
{
    _currentNode = aNode;
}

- (LKAST *)currentNode
{
    return _currentNode;
}

@end
