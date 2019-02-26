//
//  LKContinueMode.m
//  LanguageKit
//
//  Created by Graham Lee on 21/02/2019.
//

#import "LKContinueMode.h"
#import "LKDebuggerService.h"
#import "LKPauseMode.h"

@implementation LKContinueMode

- (void)onTracepoint:(LKAST *)aNode
{
    if ([self.service hasBreakpointAt:aNode]) {
        [self.service pause];
    }
}

@end
