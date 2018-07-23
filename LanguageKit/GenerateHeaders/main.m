//
//  main.m
//  GenerateHeaders
//
//  Created by Christopher Atlan on 24.06.18.
//

#import <Foundation/Foundation.h>

#import <LanguageKit/LanguageKit.h>
#import <LanguageKit/LKInterpreter.h>
#import <Smalltalk/Smalltalk.h>

static NSString *headerComment =
    @"//\n"
    @"//  %@\n"
    @"//\n"
    @"//\n"
    @"//  This file was automatically generated and should not be edited.\n"
    @"//\n\n";

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        id parser = [[[LKCompiler compilerClassForFileExtension:@"st"] parserClass] new];
        
        if ([[[NSProcessInfo processInfo] arguments] count] < 2)
        {
            exit(1);
        }
        
        NSString *inputPath = [[[NSProcessInfo processInfo] arguments] objectAtIndex:1];
        NSURL *inputURL = [NSURL fileURLWithPath:inputPath];
        SmalltalkFileWrapper *fileWrapper = [[SmalltalkFileWrapper alloc] initWithURL:inputURL options:0 error:NULL];
        
        NSString *outputPath = [[[NSProcessInfo processInfo] arguments] objectAtIndex:2];
        NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
        NSFileWrapper *outputFilerWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:[NSDictionary dictionary]];
        
        NSDictionary<NSString *, SmalltalkFileWrapper *> *classFileWrappers = [fileWrapper classFileWrappers];
        for (NSString *filename in classFileWrappers)
        {
            SmalltalkFileWrapper *classFileWrapper = [classFileWrappers objectForKey:filename];
            
            LKAST *result = [parser parseString:[classFileWrapper smalltalk]];
            if ([result isKindOfClass:[LKModule class]])
            {
                LKModule *module = (LKModule *)result;
                for (LKSubclass *subclass in [module allClasses])
                {
                    NSString *headerFilename = [[subclass classname] stringByAppendingPathExtension:@"h"];
                    NSMutableString *header = [NSMutableString stringWithFormat:headerComment, headerFilename];
                    [header appendFormat:@"@interface %@ : %@\n\n", [subclass classname], [subclass superclassname]];
                    for (LKMethod *method in [subclass methods])
                    {
                        NSString *methodType = [method isKindOfClass:[LKClassMethod class]] ? @"+" : @"-";
                        NSString *selector = [[method signature] selector];
                        NSArray *selectorParts = [selector componentsSeparatedByString:@":"];
                        NSArray *arguments = [[method signature] arguments];
                        [header appendFormat:@"%@ (id)%@", methodType, [selectorParts firstObject]];
                        for (NSInteger index = 0, count = [arguments count]; index < count; index++)
                        {
                            NSString *argument = [arguments objectAtIndex:index];
                            if (index == 0)
                            {
                                [header appendFormat:@":(id)%@", argument];
                            }
                            else
                            {
                                NSInteger selectorIndex = index - 1;
                                NSString *selectorPart = [selectorParts objectAtIndex:selectorIndex];
                                [header appendFormat:@"%@:(id)%@", selectorPart, argument];
                            }
                            BOOL hasMoreArguments = (index + 1 < count);
                            if (hasMoreArguments)
                            {
                                [header appendString:@" "];
                            }
                        }
                        [header appendString:@";\n"];
                    }
                    [header appendString:@"\n@end\n\n"];
                    
                    
                    NSData *headerData = [header dataUsingEncoding:NSUTF8StringEncoding];
                    [outputFilerWrapper addRegularFileWithContents:headerData preferredFilename:headerFilename];
                }
            }
        }
        
        NSError *error = nil;
        if ([outputFilerWrapper writeToURL:outputURL options:0 originalContentsURL:nil error:&error] == NO)
        {
            exit(1);
        }
    }
    return 0;
}
