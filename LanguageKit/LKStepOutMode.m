//
//  LKStepOutMode.m
//  LanguageKit
//
//  Created by Graham Lee on 21/02/2019.
//

#import "LKStepOutMode.h"
#import "LKDebuggerService.h"
#import "LKReturn.h"

@implementation LKStepOutMode

- (void)onTracepoint:(LKAST *)aNode {
    /*
     * For avoidance of doubt, I'm making this decision I made explicit both here
     * and in the associated tests:
     * step out mode stops if it encounters a return statement OR a breakpoint.
     * I don't think we should ignore breakpoints encountered on the way out
     * of a function.
     */
    if ([aNode isKindOfClass:[LKReturn class]] || [self.service hasBreakpointAt:aNode]) {
        [self.service pause];
    }
}

@end
