//
//  LKDBClient.m
//  LanguageKit
//
//  Created by Christopher Atlan on 15.02.19.
//

#import "LKDBClient.h"

#import "LKDBConnection.h"


#pragma mark LKDBClient

@interface LKDBClient () <LKDBConnectionDelegate> {
    LKDBConnection *_internalClient;
    NSMutableDictionary *_replyBlocks;
}

@end

@implementation LKDBClient

- (instancetype)init
{
    self = [super init];
    if (self) {
        _replyBlocks = [NSMutableDictionary dictionary];
        
        NSInputStream *            inputStream = nil;
        NSOutputStream *           outputStream = nil;
        NSNetService *netService = [[NSNetService alloc] initWithDomain:@"local." type:@"_x-lkdbserver._tcp" name:@"💁 Fancy Typewriter 💁"];
        [netService resolveWithTimeout:15.0];
        if ([netService getInputStream:&inputStream outputStream:&outputStream])
        {
            _internalClient = [[LKDBConnection alloc] initWithInputStream:inputStream outputStream:outputStream];
            [_internalClient setDelegate:self];
            [_internalClient open];
        }
    }
    return self;
}

- (void)addBreakpoint:(id<NSSecureCoding>)breakpoint withReply:(void (^)(id obj, NSError *error))block
{
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:breakpoint requiringSecureCoding:YES error:&error];
    [self sendMessage:@"addBreakpoint" parameters:data withReply:block];
}

- (void)removeBreakpoint:(id<NSSecureCoding>)breakpoint withReply:(void (^)(id obj, NSError *error))block
{
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:breakpoint requiringSecureCoding:YES error:&error];
    [self sendMessage:@"removeBreakpoint" parameters:data withReply:block];
}

#pragma mark Messages

- (void)sendMessage:(NSString *)method parameters:(id)parameters withReply:(void (^)(id obj, NSError *error))block
{
    NSUInteger msgID = [_internalClient sendMessage:method object:parameters];
    NSNumber *messageID = [NSNumber numberWithUnsignedInteger:msgID];
    [_replyBlocks setObject:[block copy] forKey:messageID];
}

- (void)handleMessage:(CFHTTPMessageRef)message;
{
    NSString *messageIDStr = CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(message, CFSTR("messageID")));
    NSNumber *messageID = [NSNumber numberWithUnsignedInteger:[messageIDStr integerValue]];
    if (messageID)
    {
        void (^block)(id<NSSecureCoding>, NSError *) = [_replyBlocks objectForKey:messageID];
        if (block)
        {
            NSData *data = CFBridgingRelease(CFHTTPMessageCopyBody(message));
            NSError *error = nil;
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
            [unarchiver setRequiresSecureCoding:YES];
            id<NSSecureCoding> result = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
            block(result, error);
            [_replyBlocks removeObjectForKey:messageID];
        }
    }
}

#pragma mark Delegate

- (void)connection:(LKDBConnection *)connection handleMessage:(CFHTTPMessageRef)message
{
    [self handleMessage:message];
}

@end
