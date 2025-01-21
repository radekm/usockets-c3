module us;

import std;

distinct SocketDescriptor @if(env::WIN32) = uptr;
distinct SocketDescriptor @if(!env::WIN32) = CInt;

/* Library types publicly available */
distinct Socket = void;
distinct Timer = void;
distinct SocketContext = void;
distinct Loop = void;
distinct Poll = void;

/* Extra for io_uring */
extern fn char* socket_send_buffer(CInt ssl, Socket* s) @extern("us_socket_send_buffer");

/* Public interfaces for timers */

/* Create a new high precision, low performance timer. May fail and return null */
extern fn Timer* create_timer(Loop* loop, CInt fallthrough, CUInt ext_size) @extern("us_create_timer");

/* Returns user data extension for this timer */
extern fn void* timer_ext(Timer* timer) @extern("us_timer_ext");

extern fn void timer_close(Timer* timer) @extern("us_timer_close");

def TimerCb = fn void(Timer* t);

/* Arm a timer with a delay from now and eventually a repeat delay.
 * Specify 0 as repeat delay to disable repeating. Specify both 0 to disarm. */
extern fn void timer_set(Timer* timer, TimerCb cb, CInt ms, CInt repeat_ms) @extern("us_timer_set");

/* Returns the loop for this timer */
extern fn Loop* timer_loop(Timer* t) @extern("us_timer_loop");

/* Public interfaces for contexts */

struct SocketContextOptions
{
    ZString key_file_name;
    ZString cert_file_name;
    ZString passphrase;
    ZString dh_params_file_name;
    ZString ca_file_name;
    ZString ssl_ciphers;
    CInt ssl_prefer_low_memory_usage;
}

/* Return 15-bit timestamp for this context */
extern fn CUShort socket_context_timestamp(CInt ssl, SocketContext* context) @extern("us_socket_context_timestamp");

def OnServerNameCb = fn void(SocketContext*, ZString hostname);

/* Adds SNI domain and cert in asn1 format */
extern fn void socket_context_add_server_name(CInt ssl, SocketContext* context, ZString hostname_pattern, SocketContextOptions options, void* user) @extern("us_socket_context_add_server_name");
extern fn void socket_context_remove_server_name(CInt ssl, SocketContext* context, ZString hostname_pattern) @extern("us_socket_context_remove_server_name");
extern fn void socket_context_on_server_name(CInt ssl, SocketContext* context, OnServerNameCb cb) @extern("us_socket_context_on_server_name");
extern fn void* socket_server_name_userdata(CInt ssl, Socket* s) @extern("us_socket_server_name_userdata");
extern fn void* socket_context_find_server_name_userdata(CInt ssl, SocketContext* context, ZString hostname_pattern) @extern("us_socket_context_find_server_name_userdata");

/* Returns the underlying SSL native handle, such as SSL_CTX or nullptr */
extern fn void* socket_context_get_native_handle(CInt ssl, SocketContext* context) @extern("us_socket_context_get_native_handle");

/* A socket context holds shared callbacks and user data extension for associated sockets */
extern fn SocketContext* create_socket_context(CInt ssl, Loop* loop, CInt ext_size, SocketContextOptions options) @extern("us_create_socket_context");

/* Delete resources allocated at creation time. */
extern fn void usocket_context_free(CInt ssl, SocketContext* context) @extern("us_usocket_context_free");

def OnPreOpenCb = fn SocketDescriptor(SocketContext* context, SocketDescriptor fd);
def OnOpenCb = fn Socket*(Socket* s, CInt is_client, char* ip, CInt ip_length);
def OnCloseCb = fn Socket*(Socket* s, CInt code, void* reason);
def OnDataCb = fn Socket*(Socket* s, char* data, CInt length);
def OnWritableCb = fn Socket*(Socket* s);
def OnTimeoutCb = fn Socket*(Socket* s);
def OnConnectErrorCb = fn Socket*(Socket* s, CInt code);
def OnEndCb = fn Socket*(Socket* s);

/* Setters of various async callbacks */
extern fn void socket_context_on_pre_open(CInt ssl, SocketContext* context,
    OnPreOpenCb on_pre_open) @extern("us_socket_context_on_pre_open");
extern fn void socket_context_on_open(CInt ssl, SocketContext* context,
    OnOpenCb on_open) @extern("us_socket_context_on_open");
extern fn void socket_context_on_close(CInt ssl, SocketContext* context,
    OnCloseCb on_close) @extern("us_socket_context_on_close");
extern fn void socket_context_on_data(CInt ssl, SocketContext* context,
    OnDataCb on_data) @extern("us_socket_context_on_data");
extern fn void socket_context_on_writable(CInt ssl, SocketContext* context,
    OnWritableCb on_writable) @extern("us_socket_context_on_writable");
extern fn void socket_context_on_timeout(CInt ssl, SocketContext* context,
    OnTimeoutCb on_timeout) @extern("us_socket_context_on_timeout");
extern fn void socket_context_on_long_timeout(CInt ssl, SocketContext* context,
    OnTimeoutCb on_timeout) @extern("us_socket_context_on_long_timeout");
/* This one is only used for when a connecting socket fails in a late stage. */
extern fn void socket_context_on_connect_error(CInt ssl, SocketContext* context,
    OnConnectErrorCb on_connect_error) @extern("us_socket_context_on_connect_error");

/* Emitted when a socket has been half-closed */
extern fn void socket_context_on_end(CInt ssl, SocketContext* context, OnEndCb on_end) @extern("us_socket_context_on_end");

/* Returns user data extension for this socket context */
extern fn void* socket_context_ext(CInt ssl, SocketContext* context) @extern("us_socket_context_ext");

/* Closes all open sockets, including listen sockets. Does not invalidate the socket context. */
extern fn void socket_context_close(CInt ssl, SocketContext* context) @extern("us_socket_context_close");

distinct ListenSocket = void;

/* Listen for connections. Acts as the main driving cog in a server. Will call set async callbacks. */
extern fn ListenSocket* socket_context_listen(CInt ssl, SocketContext* context,
    ZString host, CInt port, CInt options, CInt socket_ext_size) @extern("us_socket_context_listen");

extern fn ListenSocket* socket_context_listen_unix(CInt ssl, SocketContext* context,
    ZString path, CInt options, CInt socket_ext_size) @extern("us_socket_context_listen_unix");

/* listen_socket.c/.h */
extern fn void listen_socket_close(CInt ssl, ListenSocket* ls) @extern("us_listen_socket_close");

/* Adopt a socket which was accepted either internally, or from another accept() outside libusockets */
extern fn Socket* adopt_accepted_socket(CInt ssl, SocketContext* context, SocketDescriptor client_fd,
    CUInt socket_ext_size, char *addr_ip, CInt addr_ip_length) @extern("us_adopt_accepted_socket");

/* Land in on_open or on_connection_error or return null or return socket */
extern fn Socket* socket_context_connect(CInt ssl, SocketContext* context,
    ZString host, CInt port, ZString source_host, CInt options, CInt socket_ext_size) @extern("us_socket_context_connect");

extern fn Socket* socket_context_connect_unix(CInt ssl, SocketContext* context,
    ZString server_path, CInt options, CInt socket_ext_size) @extern("us_socket_context_connect_unix");

/* Is this socket established? Can be used to check if a connecting socket has fired the on_open event yet.
 * Can also be used to determine if a socket is a listen_socket or not, but you probably know that already. */
extern fn CInt socket_is_established(CInt ssl, Socket* s) @extern("us_socket_is_established");

/* Cancel a connecting socket. Can be used together with socket_timeout to limit connection times.
 * Entirely destroys the socket - this function works like socket_close but does not trigger on_close event since
 * you never got the on_open event first. */
extern fn Socket* socket_close_connecting(CInt ssl, Socket* s) @extern("us_socket_close_connecting");

/* Returns the loop for this socket context. */
extern fn Loop* socket_context_loop(CInt ssl, SocketContext* context) @extern("us_socket_context_loop");

/* Invalidates passed socket, returning a new resized socket which belongs to a different socket context.
 * Used mainly for "socket upgrades" such as when transitioning from HTTP to WebSocket. */
extern fn Socket* socket_context_adopt_socket(CInt ssl, SocketContext* context, Socket* s, CInt ext_size) @extern("us_socket_context_adopt_socket");

/* Create a child socket context which acts much like its own socket context with its own callbacks yet still relies on the
 * parent socket context for some shared resources. Child socket contexts should be used together with socket adoptions and nothing else. */
extern fn SocketContext* create_child_socket_context(CInt ssl, SocketContext* context, CInt context_ext_size) @extern("us_create_child_socket_context");

/* Public interfaces for loops */

def LoopCb = fn void(Loop* loop);

/* Returns a new event loop with user data extension */
extern fn Loop* create_loop(void* hint, LoopCb wakeup_cb,
    LoopCb pre_cb, LoopCb post_cb, CUInt ext_size) @extern("us_create_loop");

/* Frees the loop immediately */
extern fn void loop_free(Loop* loop) @extern("us_loop_free");

/* Returns the loop user data extension */
extern fn void* loop_ext(Loop* loop) @extern("us_loop_ext");

/* Blocks the calling thread and drives the event loop until no more non-fallthrough polls are scheduled */
extern fn void loop_run(Loop* loop) @extern("us_loop_run");

/* Signals the loop from any thread to wake up and execute its wakeup handler from the loop's own running thread.
 * This is the only fully thread-safe function and serves as the basis for thread safety */
extern fn void wakeup_loop(Loop* loop) @extern("us_wakeup_loop");

/* Hook up timers in existing loop */
extern fn void loop_integrate(Loop* loop) @extern("us_loop_integrate");

/* Returns the loop iteration number */
extern fn CLongLong loop_iteration_number(Loop* loop) @extern("us_loop_iteration_number");

/* Public interfaces for polls */

/* A fallthrough poll does not keep the loop running, it falls through */
extern fn Poll* create_poll(Loop* loop, CInt fallthrough, CUInt ext_size) @extern("us_create_poll");

/* After stopping a poll you must manually free the memory */
extern fn void poll_free(Poll* p, Loop* loop) @extern("us_poll_free");

/* Associate this poll with a socket descriptor and poll type */
extern fn void poll_init(Poll* p, SocketDescriptor fd, CInt poll_type) @extern("us_poll_init");

/* Start, change and stop polling for events */
extern fn void poll_start(Poll* p, Loop* loop, CInt events) @extern("us_poll_start");
extern fn void poll_change(Poll* p, Loop* loop, CInt events) @extern("us_poll_change");
extern fn void poll_stop(Poll* p, Loop* loop) @extern("us_poll_stop");

/* Return what events we are polling for */
extern fn CInt poll_events(Poll* p) @extern("us_poll_events");

/* Returns the user data extension of this poll */
extern fn void* poll_ext(Poll* p) @extern("us_poll_ext");

/* Get associated socket descriptor from a poll */
extern fn SocketDescriptor poll_fd(Poll* p) @extern("us_poll_fd");

/* Resize an active poll */
extern fn Poll* poll_resize(Poll* p, Loop* loop, CUInt ext_size) @extern("us_poll_resize");

/* Public interfaces for sockets */

/* Returns the underlying native handle for a socket, such as SSL or file descriptor.
 * In the case of file descriptor, the value of pointer is fd. */
extern fn void* socket_get_native_handle(CInt ssl, Socket* s) @extern("us_socket_get_native_handle");

/* Write up to length bytes of data. Returns actual bytes written.
 * Will call the on_writable callback of active socket context on failure to write everything off in one go.
 * Set hint msg_more if you have more immediate data to write. */
extern fn CInt socket_write(CInt ssl, Socket* s, char* data, CInt length, CInt msg_more) @extern("us_socket_write");

/* Special path for non-SSL sockets. Used to send header and payload in one go. Works like socket_write. */
extern fn CInt socket_write2(CInt ssl, Socket* s, char* header, CInt header_length, char* payload, CInt payload_length) @extern("us_socket_write2");

/* Set a low precision, high performance timer on a socket. A socket can only have one single active timer
 * at any given point in time. Will remove any such pre set timer */
extern fn void socket_timeout(CInt ssl, Socket* s, CUInt seconds) @extern("us_socket_timeout");

/* Set a low precision, high performance timer on a socket. Suitable for per-minute precision. */
extern fn void socket_long_timeout(CInt ssl, Socket* s, CUInt minutes) @extern("us_socket_long_timeout");

/* Return the user data extension of this socket */
extern fn void* socket_ext(CInt ssl, Socket* s) @extern("us_socket_ext");

/* Return the socket context of this socket */
extern fn SocketContext* socket_context(CInt ssl, Socket* s) @extern("us_socket_context");

/* Withdraw any msg_more status and flush any pending data */
extern fn void socket_flush(CInt ssl, Socket* s) @extern("us_socket_flush");

/* Shuts down the connection by sending FIN and/or close_notify */
extern fn void socket_shutdown(CInt ssl, Socket* s) @extern("us_socket_shutdown");

/* Shuts down the connection in terms of read, meaning next event loop
 * iteration will catch the socket being closed. Can be used to defer closing
 * to next event loop iteration. */
extern fn void socket_shutdown_read(CInt ssl, Socket* s) @extern("us_socket_shutdown_read");

/* Returns whether the socket has been shut down or not */
extern fn CInt socket_is_shut_down(CInt ssl, Socket* s) @extern("us_socket_is_shut_down");

/* Returns whether this socket has been closed. Only valid if memory has not yet been released. */
extern fn CInt socket_is_closed(CInt ssl, Socket* s) @extern("us_socket_is_closed");

/* Immediately closes the socket */
extern fn Socket* socket_close(CInt ssl, Socket* s, CInt code, void* reason) @extern("us_socket_close");

/* Returns local port or -1 on failure. */
extern fn CInt socket_local_port(CInt ssl, Socket* s) @extern("us_socket_local_port");

/* Returns remote ephemeral port or -1 on failure. */
extern fn CInt socket_remote_port(CInt ssl, Socket* s) @extern("us_socket_remote_port");

/* Copy remote (IP) address of socket, or fail with zero length. */
extern fn void socket_remote_address(CInt ssl, Socket* s, char* buf, CInt* length) @extern("us_socket_remote_address");
