
import std;
import us;

def Socket = us::Socket;

const CInt SSL = 1;

/* Our socket extension */
struct EchoSocket
{
    char[] backpressure;
}

/* Our socket context extension */
struct EchoContext
{
    int dummy;  // Empty structs are not allowed in C3.
}

/* Loop wakeup handler */
fn void on_wakeup(Loop* loop)
{
    io::printfn("Loop wakeup");
}

/* Loop pre iteration handler */
fn void on_pre(Loop* loop)
{
    io::printfn("Loop pre");
}

/* Loop post iteration handler */
fn void on_post(Loop* loop)
{
    io::printfn("Loop post");
}

/* Socket writable handler */
fn Socket* on_echo_socket_writable(Socket *s)
{
    EchoSocket* es = (EchoSocket*)us::socket_ext(SSL, s);

    /* Continue writing out our backpressure */
    CInt written = us::socket_write(SSL, s, es.backpressure.ptr, es.backpressure.len, 0);
    if (written != es.backpressure.len)
    {
        char[] new_buffer = mem::alloc_array(char, es.backpressure.len - written);
        mem::copy(new_buffer.ptr, es.backpressure.ptr + written, es.backpressure.len - written);
        free(es.backpressure);
        es.backpressure = new_buffer;
    }
    else
    {
        free(es.backpressure);
        es.backpressure = {};
    }

    /* Client is not boring */
    us::socket_timeout(SSL, s, 30);

    return s;
}

/* Socket closed handler */
fn Socket* on_echo_socket_close(Socket* s, CInt code, void* reason)
{
    EchoSocket* es = (EchoSocket*)us::socket_ext(SSL, s);

    io::printfn("Client disconnected");

    free(es.backpressure);

    return s;
}

/* Socket half-closed handler */
fn Socket* on_echo_socket_end(Socket* s)
{
    us::socket_shutdown(SSL, s);
    return us::socket_close(SSL, s, 0, null);
}

/* Socket data handler */
fn Socket* on_echo_socket_data(Socket* s, char* data, CInt length) {
    EchoSocket* es = (EchoSocket*)us::socket_ext(SSL, s);

    /* Print the data we received */
    io::printfn("Client sent: %s", (String)data[:length]);

    // TODO: Following code works correctly only if `us::socket_write`
    //       writes nothing until `on_echo_socket_writable` is received.
    //       Otherwise we may write new `data` before old `es.backpressure`.data.
    //       We shall verify this!

    /* Send it back or buffer it up */
    CInt written = us::socket_write(SSL, s, data, length, 0);
    if (written != length)
    {
        char[] new_buffer = mem::alloc_array(char, es.backpressure.len + length - written);
        mem::copy(new_buffer.ptr, es.backpressure.ptr, es.backpressure.len);
        mem::copy(new_buffer.ptr + es.backpressure.len, data + written, (usz)(length - written));
        free(es.backpressure);
        es.backpressure = new_buffer;
    }

    /* Client is not boring */
    us::socket_timeout(SSL, s, 30);

    return s;
}

/* Socket opened handler */
fn Socket* on_echo_socket_open(Socket* s, CInt is_client, char* ip, CInt ip_length)
{
    EchoSocket* es = (EchoSocket*)us::socket_ext(SSL, s);

    /* Initialize the new socket's extension */
    es.backpressure = {};

    /* Start a timeout to close the socket if boring */
    us::socket_timeout(SSL, s, 30);

    io::printfn("Client connected");

    return s;
}

/* Socket timeout handler */
fn Socket* on_echo_socket_timeout(Socket* s)
{
    io::printfn("Client was idle for too long");
    return us::socket_close(SSL, s, 0, null);
}

fn void main()
{
    /* The event loop */
    Loop* loop = us::create_loop(null, &on_wakeup, &on_pre, &on_post, 0);

    /* Socket context */
    SocketContextOptions options;
    options.key_file_name = "certs/valid_server_key.pem";
    options.cert_file_name = "certs/valid_server_crt.pem";

    SocketContext* echo_context = us::create_socket_context(SSL, loop, EchoContext.sizeof, options);
    if (echo_context == null)
    {
        io::printfn("Failed to create echo_context - probably problem with TLS certificates");
        return;
    }

    /* Registering event handlers */
    us::socket_context_on_open(SSL, echo_context, &on_echo_socket_open);
    us::socket_context_on_data(SSL, echo_context, &on_echo_socket_data);
    us::socket_context_on_writable(SSL, echo_context, &on_echo_socket_writable);
    us::socket_context_on_close(SSL, echo_context, &on_echo_socket_close);
    us::socket_context_on_timeout(SSL, echo_context, &on_echo_socket_timeout);
    us::socket_context_on_end(SSL, echo_context, &on_echo_socket_end);

    /* Start accepting echo sockets */
    ListenSocket* listen_socket = us::socket_context_listen(SSL, echo_context, null, 3000, 0, EchoSocket.sizeof);

    if (listen_socket)
    {
        io::printfn("Listening on port 3000...");
        us::loop_run(loop);
    }
    else
    {
        io::printfn("Failed to listen!");
    }
}
