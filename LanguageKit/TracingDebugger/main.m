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
    NSLog(@"Encountered AST node: %@", aNode);
}

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
        [debugger setMode:[TracingMode new]];
        [debugger debugScript:module];
    }
    return 0;
}
