//
//  LKDBConnection.m
//  LanguageKit
//
//  Created by Christopher Atlan on 16.02.19.
//

#import "LKDBConnection.h"



NSString * kQCommandConnectionErrorDomain = @"com.apple.dts.kQCommandConnectionErrorDomain";

@interface LKDBConnection () <NSStreamDelegate> {
    NSMutableData *    _inputBuffer;
    NSMutableData *    _outputBuffer;
    BOOL               _hasSpaceAvailable;
    NSUInteger         _messageID;
    NSMutableData *    _messageBuffer;
    CFHTTPMessageRef   _message;
}

@property (nonatomic, retain, readonly ) NSMutableSet *     runLoopModesMutable;
@property (nonatomic, assign, readwrite) BOOL               isOpen;

@end

@implementation LKDBConnection

// See comment in header.
- (id)initWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    assert(inputStream != nil);
    assert(outputStream != nil);
    self = [super init];
    if (self != nil) {
        _inputStream  = inputStream;
        _outputStream = outputStream;
        _runLoopModesMutable = [[NSMutableSet alloc] initWithObjects:NSDefaultRunLoopMode, nil];
        assert(_runLoopModesMutable != nil);
    }
    return self;
}

#pragma mark Run loop modes

- (void)addRunLoopMode:(NSString *)modeToAdd
{
    assert(modeToAdd != nil);
    if ( ! _isOpen ) {
        [_runLoopModesMutable addObject:modeToAdd];
    }
}

- (void)removeRunLoopMode:(NSString *)modeToRemove
{
    assert(modeToRemove != nil);
    if ( ! _isOpen ) {
        [_runLoopModesMutable removeObject:modeToRemove];
    }
}

- (NSSet *)runLoopModes
{
    return [_runLoopModesMutable copy];
}

#pragma mark Utilities

- (void)logWithFormat:(NSString *)format arguments:(va_list)argList
{
    assert(format != nil);
    id<LKDBConnectionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(connection:logWithFormat:arguments:)]) {
        [delegate connection:self logWithFormat:format arguments:argList];
    }
}

- (void)logWithFormat:(NSString *)format, ...
{
    va_list argList;
    
    assert(format != nil);
    va_start(argList, format);
    [self logWithFormat:format arguments:argList];
    va_end(argList);
}

// Creates an error in the kQCommandConnectionErrorDomain domain
// with the specified code and (not really) user-visible string.
+ (NSError *)errorWithCode:(NSInteger)code
{
    NSDictionary *   userInfo;
    NSString *              description;
    
    assert(code != 0);
    
    userInfo = nil;
    
    switch (code) {
        case kQCommandConnectionOutputBufferFullError: {
            description = @"output buffer full";
        } break;
        case kQCommandConnectionInputBufferFullError: {
            description = @"input buffer full";
        } break;
        case kQCommandConnectionOutputCommandTooLongError: {
            description = @"output command too long";
        } break;
        case kQCommandConnectionInputUnexpectedError: {
            description = @"did not expect input on this connection";
        } break;
        case kQCommandConnectionInputCommandTooLongError: {
            description = @"input command too long";
        } break;
        case kQCommandConnectionInputCommandMalformedError: {
            description = @"input command malformed";
        } break;
        default: {
            assert(NO);
            description = nil;
        } break;
    }
    
    if (description != nil) {
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                    description, NSLocalizedDescriptionKey,
                    nil
                    ];
        assert(userInfo != nil);
    }
    return [NSError errorWithDomain:kQCommandConnectionErrorDomain code:code userInfo:userInfo];
}

#pragma mark Open and close

// See comment in header.
- (void)open
{
    assert( ! _isOpen );
    
    [self logWithFormat:@"open"];
    
    // Set up the input and output buffers.
    
    if (_inputBufferCapacity == 0) {
        _inputBufferCapacity = 16 * 1024;
    }
    _inputBuffer  = [NSMutableData dataWithCapacity:_inputBufferCapacity];
    assert(_inputBuffer != nil);
    _outputBuffer = [NSMutableData dataWithCapacity:_inputBufferCapacity];
    assert(_outputBuffer != nil);
    _messageBuffer  = [NSMutableData dataWithCapacity:_inputBufferCapacity];
    assert(_messageBuffer != nil);
    
    // Start the streams.
    
    [_inputStream  setDelegate:self];
    [_outputStream setDelegate:self];
    
    for (NSString * mode in _runLoopModesMutable) {
        [_inputStream  scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
        [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
    }
    
    [_inputStream  open];
    [_outputStream open];
    
    self.isOpen = YES;
}

// See comment in header.
- (void)willCloseWithError:(NSError *)error
{
    // error may be nil (indicates EOF)
    id<LKDBConnectionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(connection:willCloseWithError:)]) {
        [delegate connection:self willCloseWithError:error];
    }
}

// Closes the stream and, if notify is YES, tells the delegate about it.
// This is the core code for the -close and -closeWithError: public
// methods.
- (void)closeWithError:(NSError *)error notify:(BOOL)notify
{
    // error may be nil (indicates EOF)
    if (_isOpen) {
        // Latch the error.
        
        if (_error == nil) {
            _error = error;
        }
        
        // Inform the delegate, if required.
        
        if (notify) {
            // The following retain and autorelease is necessary to prevent crashes when,
            // after we tell the delegate about the close, the delegate releases its reference
            // to us, and that's the last reference, so we end up freed, and hence crash on
            // returning back up the stack to this code.
            
            //[[self retain] autorelease];
            
            [self willCloseWithError:error];
        }
        
        // Tear down the streams.
        
        [_inputStream  setDelegate:nil];
        [_outputStream setDelegate:nil];
        
        for (NSString * mode in _runLoopModesMutable) {
            [_inputStream  removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
            [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
        }
        
        [_inputStream  close];
        [_outputStream close];
        
        self.isOpen = NO;
    }
}

// See comment in header.
- (void)closeWithError:(NSError *)error
{
    if (error == nil) {
        [self logWithFormat:@"close without error"];
    } else {
        [self logWithFormat:@"close with error %@", error];
    }
    [self closeWithError:error notify:YES];
}

// See comment in header.
- (void)close
{
    [self logWithFormat:@"close"];
    [self closeWithError:nil notify:NO];
}

#pragma mark Send and receive

// Called when data arrives on the connection.  The delegate is expected to parse the
// data to see if there's a complete command present.  If so, it should consume the
// command and return the number of bytes consumed.  If not, it should return 0
// and will be called again when the next chunk of data arrives.
//
// It is more efficient if the delegate parses out multiple commands in one call,
// but that is not strictly necessary.
//
// If the delegate detects some sort of failure it is reasonable for it to force
// the connection to close by calling -closeWithError:.
//
// If the delegate does not implement this method, any data arriving on the input stream
// will cause the connection to fail with kQCommandConnectionInputUnexpectedError.
- (NSUInteger)parseMessageData:(NSData *)data
{
    NSUInteger  result;
    
    assert(data != nil);
    assert([data length] != 0);
    
    [_messageBuffer appendData:data];
    NSData *remainingData = data;
    do {
        if (_message == NULL) {
            _message = CFHTTPMessageCreateEmpty(NULL, NO);
        }
        CFHTTPMessageAppendBytes(_message, [remainingData bytes], [remainingData length]);
        if (CFHTTPMessageIsHeaderComplete(_message)) {
            NSDictionary *headers = (__bridge_transfer id)CFHTTPMessageCopyAllHeaderFields(_message);
            NSDictionary *contentTypeParams = nil;
            NSUInteger length = (NSUInteger)[[headers objectForKey:@"Content-Length"] integerValue];
            NSData *body = (__bridge_transfer id)CFHTTPMessageCopyBody(_message);
            if ([body length] >= length) {
                NSData *content = [body subdataWithRange:NSMakeRange(0, length)];
                CFHTTPMessageSetBody(_message, (__bridge CFDataRef)content);
                CFHTTPMessageRef messageCopy = CFHTTPMessageCreateCopy(NULL, _message);
                id<LKDBConnectionDelegate> delegate = _delegate;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ( [delegate respondsToSelector:@selector(connection:handleMessage:)] ) {
                        [delegate connection:self handleMessage:messageCopy];
                    } else {
                        [self closeWithError:[[self class] errorWithCode:kQCommandConnectionInputUnexpectedError]];
                    }
                    CFRelease(messageCopy);
                });
                CFRelease(_message);
                _message = NULL;
                remainingData = [body subdataWithRange:NSMakeRange(length, [body length] - length)];
                [_messageBuffer setData:remainingData];
            }
        }
    } while (_message == NULL && [remainingData length]);
    
    return [data length];
}

// Calls the delegate to parse all of the commands that are currently sitting
// in the input buffer.
- (void)parseCommandsInBuffer
{
    NSUInteger  inputBufferLength;
    NSData *    dataToParse;
    NSUInteger  offset;
    NSUInteger  bytesParsed;
    
    inputBufferLength = [_inputBuffer length];
    assert(inputBufferLength != 0);
    assert(inputBufferLength <= _inputBufferCapacity);
    
    // We retain the data here because we're going to release it at the end.
    // This allows us to, inside the loop, create a sub-range of data and
    // have all the retains and releases work out.  This means that the
    // delegate gets a retained pointer to our input buffer for the first call
    // and an immutable copy of a sub-range of our data for subsequent calls.
    // But hey, the delegate is supposed to copy it if it wants to keep it.
    // And parse all the commands it can on each call.
    
    dataToParse = _inputBuffer;
    assert(dataToParse != nil);
    
    offset = 0;
    do {
        // Call the delegate to parse the commands in the buffer.
        
        bytesParsed = [self parseMessageData:dataToParse];
        assert(bytesParsed <= [dataToParse length]);     // you can't parse more data than we gave you
        
        // If the stream is now magically closed, the delegate closed it out from under
        // us and we need to leave.
        
        if ( ! _isOpen ) {
            break;
        }
        
        // If the delegate couldn't parse any bytes, then leave the loop and wait for the
        // remaining bytes in the command to arrive.  However, if we already passed a maximum
        // size command to the delegate and it still wasn't enough, that means the
        // client sent us a command that's too long to be parsed and the connection dies.
        
        if (bytesParsed == 0) {
            /*if ([dataToParse length] == _outputBufferCapacity) {
             [self closeWithError:[[self class] errorWithCode:kQCommandConnectionInputCommandTooLongError]];
             }*/
            break;
        }
        
        // Consume the bytes that the delegate parsed and continue parsing.  If we've consumed
        // the entire input buffer, it's time to leave.  Otherwise, create a subrange of
        // our input buffer and pass it back to the delegate.
        
        offset += bytesParsed;
        [self logWithFormat:@"parsed %zu bytes of commands", (size_t) bytesParsed];
        if (offset == inputBufferLength) {
            break;
        }
        dataToParse = [_inputBuffer subdataWithRange:NSMakeRange(offset, inputBufferLength - offset)];
        assert(dataToParse != nil);
    } while (YES);
    
    // If we consumed any bytes, remove them from the front of the input buffer.
    
    if (offset != 0) {
        [_inputBuffer replaceBytesInRange:NSMakeRange(0, offset) withBytes:NULL length:0];
    }
}

// Called in response to a NSStreamEventHasBytesAvailable event to read the data
// from the input stream and process any commands in the data.
- (void)processInput
{
    NSInteger   bytesRead;
    NSUInteger  bufferLength;
    
    bufferLength = [_inputBuffer length];
    if (bufferLength == _inputBufferCapacity) {
        [self closeWithError:[[self class] errorWithCode:kQCommandConnectionInputBufferFullError]];
    } else {
        // Temporarily increase the size of the buffer up to its capacity
        // so as to give us a space to read data.
        
        [_inputBuffer setLength:_inputBufferCapacity];
        
        // Read the actual data and respond to the three types of return values.
        
        bytesRead = [_inputStream read:((uint8_t *) [_inputBuffer mutableBytes]) + bufferLength maxLength:_inputBufferCapacity - bufferLength];
        if (bytesRead == 0) {
            [self logWithFormat:@"read EOF"];
            [self closeWithError:nil];
        } else if (bytesRead < 0) {
            assert([_inputStream streamError] != nil);
            [self logWithFormat:@"read error %@", [_inputStream streamError]];
            [self closeWithError:[_inputStream streamError]];
        } else {
            [self logWithFormat:@"read %zu bytes", (size_t) bytesRead];
            // Reset the buffer length based on the bytes we actually read and
            // then parse any received commands.
            [_inputBuffer setLength:bufferLength + bytesRead];
            [self parseCommandsInBuffer];
        }
    }
}

// Called in response to a NSStreamEventHasSpaceAvailable event (or if such
// an event was deferred) to start sending data to the output stream.
- (void)processOutput
{
    NSInteger   bytesWritten;
    
    if (_hasSpaceAvailable) {
        if ( [_outputBuffer length] != 0 ) {
            
            // Write the data and process the two types of return values.
            
            bytesWritten = [_outputStream write:[_outputBuffer bytes] maxLength:[_outputBuffer length]];
            if (bytesWritten <= 0) {
                assert([_outputStream streamError] != nil);
                [self logWithFormat:@"write error %@", [_outputStream streamError]];
                [self closeWithError:[_outputStream streamError]];
            } else {
                [self logWithFormat:@"wrote %zu bytes", (size_t) bytesWritten];
                [_outputBuffer replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
                _hasSpaceAvailable = NO;
            }
        }
    }
}

// See comment in header.
- (NSUInteger)sendMessage:(NSString *)method object:(id<NSSecureCoding>)object
{
    NSUInteger  commandLength;
    
    assert(method != nil);
    commandLength = [method length];
    assert(commandLength != 0);             // that's just silly
    
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error];
    NSString *length = [[NSNumber numberWithUnsignedInteger:[data length]] stringValue];
    
    _messageID++;
    NSNumber *messageID = [NSNumber numberWithUnsignedInteger:_messageID];
    //CFHTTPMessageRef message = CFHTTPMessageCreateRequest(NULL, CFSTR("POST"), (__bridge CFURLRef)([NSURL URLWithString:method]), kCFHTTPVersion2_0);
    CFHTTPMessageRef message = CFHTTPMessageCreateResponse(NULL, 202, NULL, kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("messageID"), (__bridge CFStringRef)[messageID stringValue]);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("method"), (__bridge CFStringRef)method);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Content-Length"), (__bridge CFStringRef)length);
    CFHTTPMessageSetBody(message, (__bridge CFDataRef)data);
    NSData *serializedMessage = CFBridgingRelease(CFHTTPMessageCopySerializedMessage(message));
    
    [self logWithFormat:@"enqueue %i byte command", [serializedMessage length]];
    [_outputBuffer appendData:serializedMessage];
    [self processOutput];
    return [messageID unsignedIntegerValue];
}

- (void)sendResponseMessageID:(NSString *)messageID object:(id<NSSecureCoding>)object
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error];
    NSString *length = [[NSNumber numberWithUnsignedInteger:[data length]] stringValue];
    
    CFHTTPMessageRef message = CFHTTPMessageCreateResponse(NULL, 202, NULL, kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("messageID"), (__bridge CFStringRef)messageID);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Content-Length"), (__bridge CFStringRef)length);
    CFHTTPMessageSetBody(message, (__bridge CFDataRef)data);
    NSData *serializedMessage = CFBridgingRelease(CFHTTPMessageCopySerializedMessage(message));
    
    [self logWithFormat:@"enqueue %i byte command", [serializedMessage length]];
    [_outputBuffer appendData:serializedMessage];
    [self processOutput];
}


// The input and output stream delegate callback method.
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    assert( (aStream == _inputStream) || (aStream == _outputStream) );
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            [self logWithFormat:@"open %@", (aStream == _inputStream) ? @"input" : @"output"];
        } break;
        case NSStreamEventHasBytesAvailable: {
            assert(aStream == _inputStream);
            [self logWithFormat:@"has bytes available"];
            [self processInput];
        } break;
        case NSStreamEventHasSpaceAvailable: {
            assert(aStream == _outputStream);
            [self logWithFormat:@"has space available"];
            _hasSpaceAvailable = YES;
            [self processOutput];
        } break;
        case NSStreamEventEndEncountered: {
            [self logWithFormat:@"EOF %@", (aStream == _inputStream) ? @"input" : @"output"];
            [self closeWithError:nil];
        } break;
        default:
            assert(NO);
            // fall through
        case NSStreamEventErrorOccurred: {
            [self logWithFormat:@"error %@ %@", (aStream == _inputStream) ? @"input" : @"output", [aStream streamError]];
            [self closeWithError:[aStream streamError]];
        } break;
    }
}

@end
