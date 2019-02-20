//
//  LKDBConnection.h
//  LanguageKit
//
//  Created by Christopher Atlan on 16.02.19.
//

#import <Foundation/Foundation.h>

// QCommandConnection is a general purpose class for managing a command-oriented
// network connection.
//
// The class is run loop based and must be called from a single thread.
// Specifically, the -open and -close methods add and remove run loop sources
// to the current thread's run loop, and it's that thread that calls the
// delegate callbacks.

@protocol LKDBConnectionDelegate;

@interface LKDBConnection : NSObject

// Creates the command connection to run over the supplied streams.
// You can set other configuration parameters, like the buffer capacities,
// before calling -open on the connection.
- (id)initWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;

// properties set on init

@property (nonatomic, retain, readonly ) NSInputStream *            inputStream;
@property (nonatomic, retain, readonly ) NSOutputStream *           outputStream;

// properties that must be configured before -open

@property (nonatomic, assign, readwrite) NSUInteger                 inputBufferCapacity;            // default is 0, meaning chose a reasonable default

// You must open or remove run loop modes before opening the connection

- (void)addRunLoopMode:(NSString *)modeToAdd;
- (void)removeRunLoopMode:(NSString *)modeToRemove;

@property (nonatomic, copy,   readonly ) NSSet *                    runLoopModes;                   // contains NSDefaultRunLoopMode by default

// properties that can be set at any time

@property (nonatomic, weak, readwrite) id<LKDBConnectionDelegate>    delegate;
@property (nonatomic, copy,   readwrite) NSString *                 name;                           // for debugging

// properties that change as the result of other actions

@property (nonatomic, assign, readonly ) BOOL                       isOpen;
@property (nonatomic, copy,   readwrite) NSError *                  error;

// actions

// Opens the connection.  It's not legal to call this if the connection has
// already been opened.  If the open fails, this calls the
// -connection:willCloseWithError: delegate method.
- (void)open;

// Closes the connection.  It is safe to call this even if -open has not called,
// or the connection has already closed.  Will not call -connection:willCloseWithError:
// delegate method (that method is only called if the connection closes by
// itself).
- (void)close;

// Closes the connection with the specified error (nil to indicate an end of file),
// much like what happens if the connection tears (or ends).  This is primarily for
// subclasses and delegates.  It is safe to call this even if -open has not called,
// or the connection has already closed.  This /will/ end up calling the
// -connection:willCloseWithError: delegate method.
- (void)closeWithError:(NSError *)error;

// Sends the specified command down the connection.  Note that there's no send-side
// flow control here.  If the connection stops sending data, eventually the buffer
// space will fill up and connection will tear.
- (NSUInteger)sendMessage:(NSString *)method object:(id<NSSecureCoding>)object;

- (void)sendResponseMessageID:(NSString *)messageID object:(id<NSSecureCoding>)object;

@end

@protocol LKDBConnectionDelegate <NSObject>

@optional

// Called when the connection fails to open or closes badly (error is not nil), or if
// there's an EOF (error is nil).
- (void)connection:(LKDBConnection *)connection willCloseWithError:(NSError *)error;


- (void)connection:(LKDBConnection *)connection handleMessage:(CFHTTPMessageRef)message;

// Called to log connection activity.
- (void)connection:(LKDBConnection *)connection logWithFormat:(NSString *)format arguments:(va_list)argList;

@end

// The following methods are exported for the benefit of subclasses.  Specifically,
// they allow subclasses to see the delegate methods without actually being the
// delegate.  The default implementation of these routines just calls the
// delegate callback, if any.

@interface LKDBConnection (ForSubclassOverride)

- (void)willCloseWithError:(NSError *)error;

- (NSUInteger)parseMessageData:(NSData *)commandData;

- (void)logWithFormat:(NSString *)format arguments:(va_list)argList;

@end

// The following methods are exported for the benefit of subclasses.

@interface LKDBConnection (ForSubclassUse)

- (void)logWithFormat:(NSString *)format, ...;
// This allows subclasses to log things to the connection delegate.

+ (NSError *)errorWithCode:(NSInteger)code;
// This allows subclasses to construct errors in the kQCommandConnectionErrorDomain.

@end

// Most connection errors come from NSStream, but some are generated internally.

extern NSString * kQCommandConnectionErrorDomain;

enum {
    kQCommandConnectionOutputBufferFullError = 1,
    kQCommandConnectionInputBufferFullError = 2,
    kQCommandConnectionOutputCommandTooLongError = 3,
    kQCommandConnectionInputUnexpectedError = 4,
    kQCommandConnectionInputCommandTooLongError = 5,
    kQCommandConnectionInputCommandMalformedError = 6       // for the benefit of our subclasses
};
