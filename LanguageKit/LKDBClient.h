//
//  LKDBClient.h
//  LanguageKit
//
//  Created by Christopher Atlan on 15.02.19.
//

#import <Foundation/Foundation.h>

@interface LKDBClient : NSObject

- (void)addBreakpoint:(id<NSSecureCoding>)breakpoint withReply:(void (^)(id obj, NSError *error))block;
- (void)removeBreakpoint:(id<NSSecureCoding>)breakpoint withReply:(void (^)(id obj, NSError *error))block;
- (void)getStatusWithReply:(void (^)(NSString *status, NSError *error))block;

@end
