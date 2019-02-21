//
//  LKRunningDebuggerMode.h
//  LanguageKit
//
//  Created by Graham Lee on 21/02/2019.
//

#import <Foundation/Foundation.h>

@class LKDebuggerService;

/**
 * This class is the superclass of all debugger modes in which the script is "running",
 * i.e. in which you can pause the debugger.
 */
@interface LKRunningDebuggerMode : NSObject

@property (nonatomic, weak) LKDebuggerService *service;

- (void)pause;
- (void)resume;
- (void)stepInto;

@end
