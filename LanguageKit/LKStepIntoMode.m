//
//  LKStepIntoMode.m
//  LanguageKit
//
//  Created by Graham Lee on 21/02/2019.
//

#import "LKStepIntoMode.h"
#import "LKDebuggerService.h"
#import "LKPauseMode.h"

@implementation LKStepIntoMode

- (void)onTracepoint:(LKAST *)aNode {
    [self.service pause];
}

@end
