//
//  LKDBServer.m
//  LanguageKit
//
//  Created by Christopher Atlan on 15.02.19.
//

#import "LKDBServer.h"

#import "LKDBConnection.h"
#import "LKDebuggerService.h"
#import "LKDebuggerStatus.h"
#import "LKLineBreakpointDescription.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>



@protocol LKDBServerInternalDelegate;

@interface LKDBServerInternal : NSObject

// Initialise the server object.  This does not actually start the server; call
// -start to do that.
//
// If type is nil, the server is not registered with Bonjour.
// If type is not nil, the server is registered in the specified
// domain with the specified name.  A domain of nil is equivalent
// to @"", that is, all standard domains.  A name of nil is equivalent
// to @"", that is, the service is given the default name.
//
// If preferredPort is 0, a dynamic port is used, otherwise preferredPort is
// used if it's not busy.  If it busy, and no type is set, the server fails
// to start.  OTOH, if type is set, the server backs off to using a dynamic port
// (the logic being that, if it's advertised with Bonjour, clients will stil
// be able to find it).
- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name preferredPort:(NSUInteger)preferredPort;

// properties set by the init method

@property (nonatomic, copy,   readonly ) NSString *             domain;         // immutable, what you passed in to -initXxx
@property (nonatomic, copy,   readonly ) NSString *             type;           // immutable, what you passed in to -initXxx
@property (nonatomic, copy,   readonly ) NSString *             name;           // immutable, what you passed in to -initXxx
@property (nonatomic, assign, readonly ) NSUInteger             preferredPort;  // mutable, but only effective on the next -start

// properties you can configure, but not between a -start and -stop

@property (nonatomic, assign, readwrite) BOOL                   disableIPv6;    // primarily for testing purposes, default is NO, only effective on next -start

// properties you can configure at any time

@property (nonatomic, assign, readwrite) id<LKDBServerInternalDelegate>    delegate;

// properties that change as the result of other actions

@property (nonatomic, assign, readonly ) NSUInteger             connectionSequenceNumber;       // observable
// This increments each time a connection is made.  It's primarily for debugging purposes.

#pragma mark Start and Stop

// It is reasonable to start and stop the same server object multiple times.

// Starts the server.  It's not legal to call this if the server is started.
// If startup attempted, will eventually call -serverDidStart: or
// -server:didStopWithError:.
- (void)start;

// Does nothing if the server is already stopped.
// This does not call -server:didStopWithError:.
// This /does/ call -server:didStopConnection: for each running connection.
- (void)stop;

@property (nonatomic, assign, readonly, getter=isStarted) BOOL  started;        // observable
@property (nonatomic, assign, readonly ) NSUInteger             registeredPort; // observable, only meaningful if isStarted is YES
@property (nonatomic, copy,   readonly ) NSString *             registeredName; // observable, only meaningful if isStarted is YES,
// may change due to Bonjour auto renaming,
// will be nil if Bonjour registration not requested,
// may be nil if Bonjour registration in progress

#pragma mark Connections

// Remove a connection from the connections set.  This does /not/ call the
// -server:closeConnection: delegate method for the connection.  A connection can
// can call this on itself.  Does nothing if the connection not in the connections set.
- (void)closeOneConnection:(id)connection;

// Closes all connections known to the server.  This /does/ call (synchronously)
// -server:closeConnection: on each connection.
- (void)closeAllConnections;

@property (nonatomic, copy,   readonly ) NSSet *                connections;

#pragma mark Run Loop Modes

// You can't add or remove run loop modes while the server is running.

- (void)addRunLoopMode:(NSString *)modeToAdd;
- (void)removeRunLoopMode:(NSString *)modeToRemove;

@property (nonatomic, copy,   readonly ) NSSet *                runLoopModes;   // contains NSDefaultRunLoopMode by default

// The following are utility methods that allow you to easily schedule streams in
// the same run loop modes as the server.

- (void)scheduleInRunLoopModesInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;
- (void)removeFromRunLoopModesInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;
// One of inputStream or outputStream may be nil.

@end


@protocol LKDBServerInternalDelegate <NSObject>

@optional

// Called after the server has fully started, that is, once the Bonjour name
// registration (if requested) is complete.  You can use registeredName to get
// the actual service name that was registered.
- (void)serverDidStart:(LKDBServerInternal *)server;

// Called when the server stops of its own accord, typically in response to some
// horrible network problem.

// You should implement one and only one of the following callbacks.  If you implement
// both, -server:connectionForSocket: is called.
- (void)server:(LKDBServerInternal *)server didStopWithError:(NSError *)error;

// Called to get a connection object for a new, incoming connection.  If you don't implement
// this, or you return nil, the socket for the connection is just closed.  If you do return
// a connection object, you are responsible for holding on to socket and ensuring that it's
// closed on the -server:closeConnection: delegate callback.
- (id)server:(LKDBServerInternal *)server connectionForSocket:(int)fd;

// Called to get a connection object for a new, incoming connection.  If you don't implement
// this, or you return nil, the incoming connection is just closed.  If you do return a
// connection object, you are responsible for opening the two streams (or just one of the
// streams, if you only need one), holding on to them, and ensuring that they are closed
// and released on the -server:closeConnection delegate callback.
- (id)server:(LKDBServerInternal *)server connectionForInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;

// Called when the server shuts down or if someone calls -closeAllConnections.
// Typically the delegate would just forward this call to the connection object itself.
- (void)server:(LKDBServerInternal *)server closeConnection:(id)connection;

// Called to log server activity.
- (void)server:(LKDBServerInternal *)server logWithFormat:(NSString *)format arguments:(va_list)argList;

@end


// The methods in this category are for subclassers only.  Client code would not
// be expected to use any of this.

// QServer uses a reasonable default algorithm for binding its listening sockets.
// Specifically:
//
// A. IPv4 is always enabled.  IPv6 is enabled if it's present on the system and is
//    not explicitly disabled using disableIPv6.
// B. It always binds IPv4 and IPv6 (if enabled) to the same port.
// C. If preferredPort is zero, binding is very likely to succeed with registeredPort set to
//    some dynamic port.
// D. If preferredPort is non-zero and type is nil, it either binds to the preferred
//    port or fails to start up.
// E. If preferredPort is non-zero and type is set, it first tries to bind to the preferred
//    port but, if that fails, uses a dynamic port.
//
// If this algorithm is not appropriate for your application you can override it by
// subclassing QServer and overriding the -listenOnPortError: method.  Any listening
// sockets that you create should be registered with run loop by calling -addListeningSocket:.
@interface LKDBServerInternal (ForSubclassers)

// Override this method to change the binding algorithm used by QServer.  The method
// must return the port number to which you bound (all listening sockets must be bound
// to the same port lest you confuse Bonjour).  If it returns 0 and errorPtr is not NULL,
// then *errorPtr must be an NSError indicating the reason for the failure.
- (NSUInteger)listenOnPortError:(NSError **)errorPtr;

// Adds the specified listening socket to the run loop (well, to the set of sockets
// that get added to the run loop when you start the server).  You should only call
// this from a -listenOnPortError: override.
- (void)addListeningSocket:(int)fd;

// The following methods allow subclasses to see the delegate methods without actually
// being the delegate.  The default implementation of these routines just calls the
// delegate callback, if any (except for -connectionForSocket:, which does the
// -server:connectionForSocket: / -server:connectionForInputStream:outputStream: dance;
// see the code for the details).

- (void)didStart;
- (void)didStopWithError:(NSError *)error;
- (id)connectionForSocket:(int)fd;
// There is no -connectionForInputStream:outputStream:.  A subclasser must override
// -connectionForSocket:.
//
// -(id)connectionForInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;
- (void)closeConnection:(id)connection;
- (void)logWithFormat:(NSString *)format arguments:(va_list)argList;

@end

@interface LKDBServerInternal () <NSNetServiceDelegate>

// read/write versions of public properties

@property (nonatomic, assign, readwrite) NSUInteger             connectionSequenceNumber;

@property (nonatomic, assign, readwrite) NSUInteger             registeredPort;
@property (nonatomic, copy,   readwrite) NSString *             registeredName;

@property (nonatomic, retain, readonly ) NSMutableSet *         connectionsMutable;
@property (nonatomic, retain, readwrite) NSMutableSet *         runLoopModesMutable;

// private properties

@property (nonatomic, retain, readonly ) NSMutableSet *         listeningSockets;
@property (nonatomic, retain, readwrite) NSNetService *         netService;

// forward declarations

static void ListeningSocketCallback(CFSocketRef sock, CFSocketCallBackType type, CFDataRef address, const void *data, void *info);

- (void)connectionAcceptedWithSocket:(int)fd;

@end

@implementation LKDBServerInternal

#pragma mark Init and Dealloc

- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name preferredPort:(NSUInteger)preferredPort
// See comment in header.
{
    assert( (type != nil) || ( (domain == nil) && (name == nil) ) );
    assert(preferredPort < 65536);
    self = [super init];
    if (self != nil) {
        _domain = [domain copy];
        _type   = [type   copy];
        _name   = [name   copy];
        _preferredPort = preferredPort;
        
        _connectionsMutable = [[NSMutableSet alloc] init];
        assert(_connectionsMutable != nil);
        _runLoopModesMutable = [[NSMutableSet alloc] initWithObjects:NSDefaultRunLoopMode, nil];
        assert(_runLoopModesMutable != nil);
        _listeningSockets = [[NSMutableSet alloc] init];
        assert(_listeningSockets != nil);
    }
    return self;
}

- (void)dealloc
{
    [self stop];
    
    // The following should have be deallocated by the call to -stop, above.
    assert( [_listeningSockets count] == 0 );
    assert(_netService == nil);
}

- (NSSet *)connections
// For public consumption, we return an immutable snapshot of the connection set.
{
    return [_connectionsMutable copy];
}

#pragma mark Utilities

// See comment in header.
- (void)logWithFormat:(NSString *)format arguments:(va_list)argList
{
    assert(format != nil);
    id<LKDBServerInternalDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(server:logWithFormat:arguments:)]) {
        [delegate server:self logWithFormat:format arguments:argList];
    }
}

// Logs the specified text.
- (void)logWithFormat:(NSString *)format, ...
{
    va_list argList;
    
    assert(format != nil);
    va_start(argList, format);
    [self logWithFormat:format arguments:argList];
    va_end(argList);
}

#pragma mark BSD Sockets wrappers

// These routines are simple wrappers around BSD Sockets APIs that turn them into some
// more palatable to Cocoa.  Without these wrappers, the code in -listenOnPortError:
// looks incredibly ugly.

// Wrapper for setsockopt.
- (int)setOption:(int)option atLevel:(int)level onSocket:(int)fd
{
    int     err;
    static const int kOne = 1;
    
    assert(fd >= 0);
    
    err = setsockopt(fd, level, option, &kOne, sizeof(kOne));
    if (err < 0) {
        err = errno;
        assert(err != 0);
    }
    return err;
}

// Wrapper for bind, including a SO_REUSEADDR setsockopt.
- (int)bindSocket:(int)fd toPort:(NSUInteger)port inAddressFamily:(int)addressFamily
{
    int                     err;
    struct sockaddr_storage addr;
    struct sockaddr_in *    addr4Ptr;
    struct sockaddr_in6 *   addr6Ptr;
    
    assert(fd >= 0);
    assert(port < 65536);
    
    err = 0;
    if (port != 0) {
        err = [self setOption:SO_REUSEADDR atLevel:SOL_SOCKET onSocket:fd];
    }
    if (err == 0) {
        memset(&addr, 0, sizeof(addr));
        addr.ss_family = addressFamily;
        if (addressFamily == AF_INET) {
            addr4Ptr = (struct sockaddr_in *) &addr;
            addr4Ptr->sin_len  = sizeof(*addr4Ptr);
            addr4Ptr->sin_port = htons(port);
        } else {
            assert(addressFamily == AF_INET6);
            addr6Ptr = (struct sockaddr_in6 *) &addr;
            addr6Ptr->sin6_len  = sizeof(*addr6Ptr);
            addr6Ptr->sin6_port = htons(port);
        }
        err = bind(fd, (const struct sockaddr *) &addr, addr.ss_len);
        if (err < 0) {
            err = errno;
            assert(err != 0);
        }
    }
    return err;
}

// Wrapper for getsockname.
- (int)boundPort:(NSUInteger *)portPtr forSocket:(int)fd
{
    int                     err;
    struct sockaddr_storage addr;
    socklen_t               addrLen;
    
    assert(fd >= 0);
    assert(portPtr != NULL);
    
    addrLen = sizeof(addr);
    err = getsockname(fd, (struct sockaddr *) &addr, &addrLen);
    if (err < 0) {
        err = errno;
        assert(err != 0);
    } else {
        if (addr.ss_family == AF_INET) {
            assert(addrLen == sizeof(struct sockaddr_in));
            *portPtr = ntohs(((const struct sockaddr_in *) &addr)->sin_port);
        } else {
            assert(addr.ss_family == AF_INET6);
            assert(addrLen == sizeof(struct sockaddr_in6));
            *portPtr = ntohs(((const struct sockaddr_in6 *) &addr)->sin6_port);
        }
    }
    return err;
}

// Wrapper for listen.
- (int)listenOnSocket:(int)fd
{
    int     err;
    
    assert(fd >= 0);
    
    err = listen(fd, 5);
    if (err < 0) {
        err = errno;
        assert(err != 0);
    }
    return err;
}

// Wrapper for close.
- (void)closeSocket:(int)fd
{
    int     junk;
    
    if (fd != -1) {
        assert(fd >= 0);
        junk = close(fd);
        assert(junk == 0);
    }
}

#pragma mark Start and Stop

+ (NSSet *)keyPathsForValuesAffectingStarted
{
    return [NSSet setWithObject:@"preferredPort"];
}

- (BOOL)isStarted
{
    return _registeredPort != 0;
}

// See comment in header.
- (void)addListeningSocket:(int)fd
{
    CFSocketContext     context = { 0, (__bridge void *)self, NULL, NULL, NULL };
    CFSocketRef         sock;
    CFRunLoopSourceRef  rls;
    
    assert(fd >= 0);
    
    sock = CFSocketCreateWithNative(NULL, fd, kCFSocketAcceptCallBack, ListeningSocketCallback, &context);
    if (sock != NULL) {
        assert( CFSocketGetSocketFlags(sock) & kCFSocketCloseOnInvalidate );
        rls = CFSocketCreateRunLoopSource(NULL, sock, 0);
        assert(rls != NULL);
        
        for (NSString * mode in _runLoopModesMutable) {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, (CFStringRef) mode);
        }
        
        CFRelease(rls);
        CFRelease(sock);
        
        [_listeningSockets addObject:(__bridge id)sock];
    }
}

// See comment in header.
- (NSUInteger)listenOnPortError:(NSError **)errorPtr
{
    int         err;
    int         fd4;
    int         fd6;
    BOOL        retry;
    NSUInteger  retryCount;
    NSUInteger  requestedPort;
    NSUInteger  boundPort;
    
    // errorPtr may be nil
    // initial value of *errorPtr undefined
    
    boundPort = 0;
    fd4 = -1;
    fd6 = -1;
    retryCount = 0;
    requestedPort = _preferredPort;
    assert(requestedPort < 65536);
    do {
        assert(fd4 == -1);
        assert(fd6 == -1);
        retry = NO;
        
        // Create our sockets.  We have to do this inside the loop because BSD Sockets
        // doesn't support unbind (bring back Open Transport!) and we may need to unbind
        // when retrying.
        
        err = 0;
        fd4 = socket(AF_INET, SOCK_STREAM, 0);
        if (fd4 < 0) {
            err = errno;
            assert(err != 0);
        }
        if ( (err == 0) && ! _disableIPv6 ) {
            fd6 = socket(AF_INET6, SOCK_STREAM, 0);
            if (fd6 < 0) {
                err = errno;
                assert(err != 0);
            }
            if (err == EAFNOSUPPORT) {
                // No IPv6 support.  Leave fd6 set to -1.
                assert(fd6 == -1);
                err = 0;
            }
        }
        
        // Bind the IPv4 socket to the specified port (may be 0).
        
        if (err == 0) {
            err = [self bindSocket:fd4 toPort:requestedPort inAddressFamily:AF_INET];
            
            // If we tried to bind to a preferred port and that failed because the
            // port is in use, and we're registering with Bonjour (meaning that
            // there's a chance that our clients can find us on a non-standard port),
            // try binding to 0, which causes the kernel to choose a port for us.
            
            if ( (err == EADDRINUSE) && (requestedPort != 0) && (_type != nil) && (retryCount < 15) ) {
                requestedPort = 0;
                retryCount += 1;
                retry = YES;
            }
        }
        if (err == 0) {
            err = [self listenOnSocket:fd4];
        }
        
        // Figure out what port we actually bound too.
        
        if (err == 0) {
            err = [self boundPort:&boundPort forSocket:fd4];
        }
        
        // Try to bind the IPv6 socket, if any, to that port.
        
        if ( (err == 0) && (fd6 != -1) ) {
            
            // Have the IPv6 socket only bind to the IPv6 address.  Without this the IPv6 socket
            // binds to dual mode address (reported by netstat as "tcp46") and that prevents a
            // second instance of the code getting the EADDRINUSE error on the IPv4 bind, which is
            // the place we're expecting it, and where we recover from it.
            
            err = [self setOption:IPV6_V6ONLY atLevel:IPPROTO_IPV6 onSocket:fd6];
            
            if (err == 0) {
                assert(boundPort != 0);
                err = [self bindSocket:fd6 toPort:boundPort inAddressFamily:AF_INET6];
                
                if ( (err == EADDRINUSE) && (requestedPort == 0) && (retryCount < 15) ) {
                    // If the IPv6 socket's bind failed and we are trying to bind
                    // to an anonymous port, try again.  This protects us from the
                    // race condition where we bind IPv4 to a port then, before we can
                    // bind IPv6 to the same port, someone else binds their own IPv6
                    // to that port (or vice versa).  We also limit the number of retries
                    // to guarantee we don't loop forever in some pathological case.
                    
                    retryCount += 1;
                    retry = YES;
                }
                
                if (err == 0) {
                    err = [self listenOnSocket:fd6];
                }
            }
        }
        
        // If something went wrong, close down our sockets.
        
        if (err != 0) {
            [self closeSocket:fd4];
            [self closeSocket:fd6];
            fd4 = -1;
            fd6 = -1;
            boundPort = 0;
        }
    } while ( (err != 0) && retry );
    
    assert( (err == 0) == (fd4 != -1) );
    assert( (err == 0) || (fd6 == -1) );
    // On success, fd6 might still be 0, implying that IPv6 is not available.
    assert( (err == 0) == (boundPort != 0) );
    assert( (err != 0) || (requestedPort == 0) || (boundPort == requestedPort) );
    
    // Add the sockets to the run loop.
    
    if (err == 0) {
        [self addListeningSocket:fd4];
        if (fd6 != -1) {
            [self addListeningSocket:fd6];
        }
    }
    
    // Clean up.
    
    // There's no need to clean up fd4 and fd6.  We are either successful,
    // in which case they are now owned by the CFSockets in the listeningSocket
    // set, or we failed, in which case they were cleaned up on the way out
    // of the do..while loop.
    if (err != 0) {
        if (errorPtr != NULL) {
            *errorPtr = [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil];
        }
        assert(boundPort == 0);
    }
    assert( (err == 0) == (boundPort != 0) );
    assert( (err == 0) || ( (errorPtr == NULL) || (*errorPtr != nil) ) );
    
    return boundPort;
}

// See comment in header.
- (void)didStart
{
    [self logWithFormat:@"did start on port %u", (unsigned int) _registeredPort];
    id<LKDBServerInternalDelegate> delegate = _delegate;
    if ( [delegate respondsToSelector:@selector(serverDidStart:)] ) {
        [delegate serverDidStart:self];
    }
}

// See comment in header.
- (void)didStopWithError:(NSError *)error
{
    assert(error != nil);
    [self logWithFormat:@"did stop with error %@", error];
    id<LKDBServerInternalDelegate> delegate = _delegate;
    if ( [delegate respondsToSelector:@selector(server:didStopWithError:)] ) {
        [delegate server:self didStopWithError:error];
    }
}

// See comment in header.
- (void)start
{
    NSUInteger  port;
    NSError *   error;
    
    assert( ! [self isStarted] );
    
    [self logWithFormat:@"starting"];
    
    port = [self listenOnPortError:&error];
    
    // Kick off the next stage of the startup, if required, namely the Bonjour registration.
    
    if (port == 0) {
        
        // If startup failed, we tell our delegate about it immediately.
        
        assert(error != nil);
        [self didStopWithError:error];
        
    } else {
        
        // Set registeredPort, which also sets isStarted, which indicates to everyone
        // that the server is up and running.  Of course in the Bonjour case it's not
        // yet fully up, but we handle that by deferring the -didStart.
        
        self.registeredPort = port;
        
        if (_type == nil) {
            
            // Startup was successful, but there's nothing to register with Bonjour, so
            // tell the delegate about the successful start.
            
            [self didStart];
            
        } else {
            
            // Startup has succeeded so far.  Let's start the Bonjour registration.
            
            assert(port < 65536);
            _netService = [[NSNetService alloc] initWithDomain:(_domain == nil) ? @"" : _domain
                                                          type:_type
                                                          name:(_name == nil) ? @"" : _name
                                                          port:(int)port];
            assert(_netService != nil);
            
            for (NSString * mode in _runLoopModesMutable) {
                [_netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
            }
            [_netService setDelegate:self];
            [_netService publishWithOptions:0];
        }
    }
}

// An NSNetService delegate callback called when we have registered on the network.
// We respond by latching the name we registered (which may be different from the
// name we attempted to register due to auto-renaming) and telling the delegate.
- (void)netServiceDidPublish:(NSNetService *)sender
{
    assert(sender == _netService);
    assert(self.isStarted);
    
    self.registeredName = [sender name];
    [self didStart];
}

// An NSNetService delegate callback called when the service failed to register
// on the network.  We respond by shutting down the server and telling the delegate.
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
    NSNumber *  errorDomainObj;
    NSNumber *  errorCodeObj;
    int         errorDomain;
    int         errorCode;
    NSError *   error;
    
    assert(sender == _netService);
    assert(errorDict != nil);
    assert(self.isStarted);             // that is, the listen sockets should be up
    
    // Extract the information from the error dictionary.
    
    errorDomain = 0;
    errorDomainObj = [errorDict objectForKey:NSNetServicesErrorDomain];
    if ( (errorDomainObj != nil) && [errorDomainObj isKindOfClass:[NSNumber class]] ) {
        errorDomain = [errorDomainObj intValue];
    }
    
    errorCode   = 0;
    errorCodeObj = [errorDict objectForKey:NSNetServicesErrorCode];
    if ( (errorCodeObj != nil) && [errorCodeObj isKindOfClass:[NSNumber class]] ) {
        errorCode = [errorCodeObj intValue];
    }
    
    // We specifically check for Bonjour errors because they are the only thing
    // we're likely to get here.  It would be nice if CFErrorCreateWithStreamError
    // existed <rdar://problem/5845848>.
    
    if ( (errorDomain == kCFStreamErrorDomainNetServices) && (errorCode != 0) ) {
        error = [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork code:errorCode userInfo:nil];
    } else {
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTTY userInfo:nil];
    }
    assert(error != nil);
    [self stop];
    [self didStopWithError:error];
}

// An NSNetService delegate callback called when the service fails in some way.
// We respond by shutting down the server and telling the delegate.
- (void)netServiceDidStop:(NSNetService *)sender
{
    NSError *   error;
    
    assert(sender == _netService);
    assert(self.isStarted);
    
    error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTTY userInfo:nil];
    assert(error != nil);
    [self stop];
    [self didStopWithError:error];
}

// See comment in header.
- (void)stop
{
    if ( self.isStarted ) {
        [self logWithFormat:@"stopping"];
        
        [self closeAllConnections];
        
        // Close down the net service if it was started.
        
        if (_netService != nil) {
            [_netService setDelegate:nil];
            [_netService stop];
            // Don't need to call -removeFromRunLoop:forMode: because -stop takes care of that.
            _netService = nil;
        }
        if (_registeredName != nil) {
            self.registeredName = nil;
        }
        
        // Close down the listening sockets.
        
        for (id s in _listeningSockets) {
            CFSocketRef sock;
            
            sock = (__bridge CFSocketRef) s;
            assert( CFGetTypeID(sock) == CFSocketGetTypeID() );
            CFSocketInvalidate(sock);
        }
        [_listeningSockets removeAllObjects];
        
        self.registeredPort = 0;
        [self logWithFormat:@"did stop"];
    }
}

#pragma mark Connections

// The CFSocket callback associated with one of the elements of the listeningSockets set.  This is
// called when a new connection arrives.  It routes the connection to the -connectionAcceptedWithSocket:
// method.
static void ListeningSocketCallback(CFSocketRef sock, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    LKDBServerInternal *   obj;
    int         fd;
    
    obj = (__bridge LKDBServerInternal *) info;
    assert([obj isKindOfClass:[LKDBServerInternal class]]);
    
    assert([obj->_listeningSockets containsObject:(__bridge id) sock]);
#pragma unused(sock)
    assert(type == kCFSocketAcceptCallBack);
#pragma unused(type)
    assert(address != NULL);
#pragma unused(address)
    assert(data != nil);
    
    fd = * (const int *) data;
    assert(fd >= 0);
    [obj connectionAcceptedWithSocket:fd];
}

// See comment in header.
//
// We first see if the delegate implements -server:connectionForSocket:.  If so, we call that.
// If not, we see if the delegate implements -server:connectionForInputStream:outputStream:.
// If so, we create the necessary input and output streams and call that method.  If the
// delegate implements neither, we simply return nil.
- (id)connectionForSocket:(int)fd
{
    id          connection;
    
    assert(fd >= 0);
    id<LKDBServerInternalDelegate> delegate = _delegate;
    if ( [delegate respondsToSelector:@selector(server:connectionForSocket:)] ) {
        connection = [delegate server:self connectionForSocket:fd];
    } else if ( [delegate respondsToSelector:@selector(server:connectionForInputStream:outputStream:)] ) {
        BOOL                success;
        CFReadStreamRef     readStream;
        CFWriteStreamRef    writeStream;
        NSInputStream *     inputStream;
        NSOutputStream *    outputStream;
        
        CFStreamCreatePairWithSocket(NULL, fd, &readStream, &writeStream);
        
        inputStream  = (__bridge NSInputStream *)readStream;
        outputStream = (__bridge NSOutputStream *)writeStream;
        
        assert( (__bridge CFBooleanRef) [inputStream propertyForKey:(__bridge NSString *)kCFStreamPropertyShouldCloseNativeSocket] == kCFBooleanFalse );
        assert( (__bridge CFBooleanRef) [outputStream propertyForKey:(__bridge NSString *)kCFStreamPropertyShouldCloseNativeSocket] == kCFBooleanFalse );
        
        connection = [delegate server:self connectionForInputStream:inputStream outputStream:outputStream];
        
        // If the client accepted this connection, we have to flip kCFStreamPropertyShouldCloseNativeSocket
        // to true so the client streams close the socket when they're done.  OTOH, if the client denies
        // the connection, we leave kCFStreamPropertyShouldCloseNativeSocket as false because our caller
        // is going to close the socket in that case.
        
        if (connection != nil) {
            success = [inputStream setProperty:(id)kCFBooleanTrue forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket];
            assert(success);
            assert( (__bridge CFBooleanRef) [outputStream propertyForKey:(__bridge NSString *)kCFStreamPropertyShouldCloseNativeSocket] == kCFBooleanTrue );
        }
    } else {
        connection = nil;
    }
    
    return connection;
}

// Called when we receive a connection on one of our listening sockets.  We
// call our delegate to create a connection object for this connection and,
// if that succeeds, add it to our connections set.
- (void)connectionAcceptedWithSocket:(int)fd
{
    int         junk;
    id          connection;
    
    assert(fd >= 0);
    
    connection = [self connectionForSocket:fd];
    _connectionSequenceNumber += 1;
    if (connection != nil) {
        [self logWithFormat:@"start connection %p", connection];
        [_connectionsMutable addObject:connection];
    } else {
        junk = close(fd);
        assert(junk == 0);
    }
}

// See comment in header.
- (void)closeConnection:(id)connection
{
    id<LKDBServerInternalDelegate> delegate = _delegate;
    if ( [delegate respondsToSelector:@selector(server:closeConnection:)] ) {
        [delegate server:self closeConnection:connection];
    }
}

// The core code behind -closeConnection: and -closeAllConnections:.
// This removes the connection from the set and, if notify is YES,
// tells the delegate about it having been closed.
- (void)closeConnection:(id)connection notify:(BOOL)notify
{
    [self logWithFormat:@"close connection %p", connection];
    if ( [_connectionsMutable containsObject:connection] ) {
        
        // It's possible that, if a connection calls this on itself, we might
        // be holding the last reference to the connection.  To avoid crashing
        // as we unwind out of the call stack, we retain and autorelease the
        // connection.
        
        //[[connection retain] autorelease];
        
        [_connectionsMutable removeObject:connection];
        
        if (notify) {
            [self closeConnection:connection];
        }
    }
}

// See comment in header.
- (void)closeOneConnection:(id)connection
{
    [self closeConnection:connection notify:NO];
}

// See comment in header.
- (void)closeAllConnections
{
    // We can't use for..in because we're mutating while enumerating.
    do {
        id      connection;
        
        connection = [_connectionsMutable anyObject];
        if (connection == nil) {
            break;
        }
        [self closeConnection:connection notify:YES];
    } while (YES);
}

#pragma mark Run Loop Modes

- (void)addRunLoopMode:(NSString *)modeToAdd
{
    assert(modeToAdd != nil);
    if ( ! self.isStarted ) {
        [_runLoopModesMutable addObject:modeToAdd];
    }
}

- (void)removeRunLoopMode:(NSString *)modeToRemove
{
    assert(modeToRemove != nil);
    if ( ! self.isStarted ) {
        [_runLoopModesMutable removeObject:modeToRemove];
    }
}

- (NSSet *)runLoopModes
{
    return [_runLoopModesMutable copy];
}

// See comment in header.
- (void)scheduleInRunLoopModesInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    assert( (inputStream != nil) || (outputStream != nil) );
    for (NSString * mode in _runLoopModesMutable) {
        if (inputStream != nil) {
            [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
        }
        if (outputStream != nil) {
            [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
        }
    }
}

- (void)removeFromRunLoopModesInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    assert( (inputStream != nil) || (outputStream != nil) );
    for (NSString * mode in _runLoopModesMutable) {
        if (inputStream != nil) {
            [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
        }
        if (outputStream != nil) {
            [outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
        }
    }
}

@end

#pragma mark LKDBServer

@interface LKDBServer () <LKDBServerInternalDelegate, LKDBConnectionDelegate> {
    LKDBServerInternal *_serverInternal;
    LKDebuggerService *_debugger;
}

@end

@implementation LKDBServer

LKDBServer *_serverLaunchedOnStart;

+ (void)load
{
    BOOL shouldLaunchDebugger = [[NSUserDefaults standardUserDefaults] boolForKey:@"LKDebugServer"];
    if (shouldLaunchDebugger) {
        _serverLaunchedOnStart = [[LKDBServer alloc] init];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _debugger = [[LKDebuggerService alloc] init];
        [_debugger activate];
        _serverInternal = [[LKDBServerInternal alloc] initWithDomain:nil type:@"_x-lkdbserver._tcp" name:nil preferredPort:1337];
        [_serverInternal setDelegate:self];
        [_serverInternal start];
    }
    return self;
}

- (void)dealloc
{
    [_debugger deactivate];
}

#pragma mark Server delegate callbacks

- (void)serverDidStart:(LKDBServerInternal *)server
{
    assert(server == _serverInternal);
}

- (void)server:(LKDBServerInternal *)server didStopWithError:(NSError *)error
{
    assert(server == _serverInternal);
    assert(error != nil);
    //[self stop];
}

- (id)server:(LKDBServerInternal *)server connectionForInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    LKDBConnection *  connection;
    
    assert(server == _serverInternal);
    assert(inputStream  != nil);
    assert(outputStream != nil);
    
    connection = [[LKDBConnection alloc] initWithInputStream:inputStream outputStream:outputStream];
    if (connection != nil) {
        connection.delegate = self;
        connection.name = [NSString stringWithFormat:@"%zu", (size_t) _serverInternal.connectionSequenceNumber];
        
        [connection open];
    }
    return connection;
}

- (void)server:(LKDBServerInternal *)server closeConnection:(id)connection
{
    assert(server == _serverInternal);
    assert( [connection isKindOfClass:[LKDBConnection class]] );
    [(LKDBConnection *)connection close];
}

- (void)server:(LKDBServerInternal *)server logWithFormat:(NSString *)format arguments:(va_list)argList
{
    NSString *  str;
    
    assert(server == _serverInternal);
    assert(format != nil);
    
    str = [[NSString alloc] initWithFormat:format arguments:argList];
    assert(str != nil);
    NSLog(@"server %@", str);
}

#pragma mark Connection delegate callbacks

- (id<NSSecureCoding>)network_addBreakpoint:(NSData *)serialisedBreakpoint error:(NSError *__autoreleasing*)error
{
    LKLineBreakpointDescription *breakpoint = [NSKeyedUnarchiver unarchivedObjectOfClass:[LKLineBreakpointDescription class]
                                                                                fromData:serialisedBreakpoint
                                                                                   error:error];
    // You still have to test that the unarchived object is of the correct class, which I didn't expect.
    if ([breakpoint isKindOfClass:[LKLineBreakpointDescription class]]) {
        [_debugger addLineBreakpoint:breakpoint];
        return @"Added";
    }
    else {
        return nil;
    }
}

- (id<NSSecureCoding>)network_removeBreakpoint:(NSData *)serialisedBreakpoint error:(NSError *__autoreleasing*)error
{
    LKLineBreakpointDescription *breakpoint = [NSKeyedUnarchiver unarchivedObjectOfClass:[LKLineBreakpointDescription class]
                                                                                fromData:serialisedBreakpoint
                                                                                   error:error];
    if ([breakpoint isKindOfClass:[LKLineBreakpointDescription class]]) {
        [_debugger removeLineBreakpoint:breakpoint];
        return @"Removed";
    }
    else {
        return nil;
    }
}

- (id<NSSecureCoding>)network_getStatus:(NSData *)unused error:(NSError *__autoreleasing*)error
{
    LKDebuggerStatus status = [_debugger status];
    NSDictionary *responseMap = @{
                                  @(DebuggerStatusWaitingAtBreakpoint): @"Waiting",
                                  @(DebuggerStatusRunning): @"Running",
                                  @(DebuggerStatusNotRunning): @"NotRunning",
                                  };
    return responseMap[@(status)] ?: @"Unknown";
}

- (void)connection:(LKDBConnection *)connection handleMessage:(CFHTTPMessageRef)message
{
    NSString *messageIDStr = CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(message, CFSTR("messageID")));
    NSNumber *messageID = [NSNumber numberWithUnsignedInteger:[messageIDStr integerValue]];
    NSLog(@"Server handleMessage messageID %@", messageIDStr);
    NSString *method = CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(message, CFSTR("method")));
    NSString *methodSelector = [NSString stringWithFormat: @"network_%@:error:", method];
    SEL aSelector = NSSelectorFromString(methodSelector);
    if ([self respondsToSelector:aSelector]) {
        NSError *messageError = nil;
        NSError * __strong *errorPointer = &messageError;
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:aSelector]];
        [invocation setTarget:self];
        [invocation setSelector:aSelector];
        NSData *archivedParameters = CFBridgingRelease(CFHTTPMessageCopyBody(message));
        [invocation setArgument:&archivedParameters atIndex:2];
        [invocation setArgument:&errorPointer atIndex:3];
        [invocation invoke];
        id <NSSecureCoding> result;
        [invocation getReturnValue:&result];
        if (result) {
            [connection sendResponseMessageID:messageIDStr object:result];
        } else {
            [connection sendResponseMessageID:messageIDStr object:messageError];
        }
    } else {
        [connection sendResponseMessageID:messageIDStr object:[NSString stringWithFormat:@"Unknown message %@", methodSelector]];
    }
}

@end
