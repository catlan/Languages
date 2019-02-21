//
//  main.m
//  TracingDebugger
//
//  Created by Graham Lee on 19/02/2019.
//

#import <Foundation/Foundation.h>
#import <LanguageKit/LanguageKit.h>

#include <sysexits.h>

static NSString* stripScriptPreamble(NSString *script)
{
    if ([script length] > 2
        &&
        [[script substringToIndex:2] isEqualToString:@"#!"])
    {
        NSRange r = [script rangeOfString:@"\n"];
        if (r.location == NSNotFound)
        {
            script = nil;
        }
        else
        {
            script = [script substringFromIndex:r.location];
        }
    }
    return script;
}

static LKAST *parseScript(NSString *script, NSString *extension)
{
    [LKCompiler compilerClassForFileExtension:extension];
    script = stripScriptPreamble(script);
    id parser =
    [[[LKCompiler compilerClassForFileExtension:extension]
      parserClass] new];
    LKAST *module = [parser parseString:script];
    return module;
}

@interface TracingMode : NSObject <LKDebuggerMode>

@end

@implementation TracingMode

@synthesize service;

- (void)onTracepoint: (LKAST *)aNode {
    NSLog(@"Encountered AST node: %@", NSStringFromClass([aNode class]));
    NSLog(@"Variables here: %@", [self.service allVariables]);
}

- (void)pause {
    
}

- (void)resume {

}

@end

@interface NSObject (AddedInScript)

- (id)doAThing;

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSError *error = nil;
        NSString *scriptName = [[[NSUserDefaults standardUserDefaults] stringForKey:@"Script"] stringByExpandingTildeInPath];
        NSString *scriptSource = [[NSString alloc] initWithContentsOfFile:scriptName
                                                                 encoding:NSUTF8StringEncoding
                                                                    error:&error];
        if (!scriptSource) {
            fprintf(stderr, "Couldn't open script %s: %s\n",
                    [scriptName UTF8String],
                    [[error localizedFailureReason] UTF8String]);
            exit(EX_IOERR);
        }
        NSString *extension = [scriptName pathExtension];
        LKAST *module = parseScript(scriptSource, extension);
        if (![module check]) {
            fprintf(stderr, "Couldn't execute the script %s\n",
                    [scriptName UTF8String]);
            exit(EX_SOFTWARE);
        }
        LKDebuggerService *debugger = [[LKDebuggerService alloc] init];
        [debugger debugScript:module];
        
        NSObject *receiver = [NSObject new];
        /*
         * You can add a breakpoint by telling the debugger what AST node it ought to stop at.
         * A UI for this debugger would either want to help users select nodes, or translate line
         * numbers into nearest nodes to emulate instruction-based debuggers like gdb and lldb.
         *
         * You can break on any AST node, including comments! Here, I find the first statement
         * in the first method in the first category defined in the script module, and break there.
         */
        LKAST *breakpoint = [[[(LKModule *)module allCategories][0] methods][0] statements][0];
        NSLog(@"Breaking at statement: %@", breakpoint);
        [debugger addBreakpoint:breakpoint];
        /*
         * When we run the interpreted method, the debugger will pause straight away. So the first
         * thing to do is to set up another thread that tells it to resume after a timer, so that
         * we can definitely continue.
         */
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                       dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0),
                       ^{
                           NSLog(@"Current location: %@", [debugger currentNode]);
                           NSLog(@"Stepping over one instruction");
                           [debugger stepInto];
                           NSLog(@"Waiting for the debugger to do the step");
                           sleep(1);
                           NSLog(@"Now at: %@", [debugger currentNode]);
                           NSLog(@"Resuming debugger");
                           [debugger resume];
                       });
        /*
         * Run the method! You shouldn't see anything for a few seconds, because the execution is
         * paused in the debugger.
         */
        NSLog(@"Running in the debugger");
        NSLog(@"%@", [receiver doAThing]);
        /*
         * OK, we're done with that part of the demo, remove the breakpoint.
         */
        [debugger removeBreakpoint:breakpoint];
        
        /*
         * Debugger users do not really need to write their own modes and set them on the debugger.
         * This custom mode is used to show the information that's available to users of the debugger.
         */
        [debugger setMode:[TracingMode new]];
        NSLog(@"%@", [receiver doAThing]);
        
    }
    return 0;
}
