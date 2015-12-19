


import Darwin

let DEFAULT_PORT = 7000
let DEFAULT_BACKLOG = 128

var loop: UnsafeMutablePointer<uv_loop_t> = nil
var addr = sockaddr_in()

let alloc_buffer: @convention(c) (UnsafeMutablePointer<uv_handle_t>, size_t, UnsafeMutablePointer<uv_buf_t>) -> Void = { (handle, suggested_size, buf) in
    buf.memory.base = UnsafeMutablePointer<CChar>.alloc(suggested_size)
    buf.memory.len = suggested_size
}

let echo_write: @convention(c) (UnsafeMutablePointer<uv_write_t>, CInt) -> Void = { (req, status) in
    if status != 0 {
        print("Write error \(uv_strerror(status))")
    }
    req.destroy()
}


let echo_read: @convention(c) (UnsafeMutablePointer<uv_stream_t>, ssize_t, UnsafePointer<uv_buf_t>) -> Void = { (client, nread, buf) in
    if nread < 0 {
        if nread != ssize_t(UV_EOF.rawValue) {
            print("Read error \(uv_err_name(CInt(nread)))")
        }
        uv_close(UnsafeMutablePointer<uv_handle_t>(client), nil)
    } else if nread > 0 {
        let req = UnsafeMutablePointer<uv_write_t>.alloc(sizeof(uv_write_t))
        
        var wrbuf = uv_buf_init(buf.memory.base, UInt32(nread))
        uv_write(req, client, &wrbuf, 1, echo_write)
    }
    
    if buf.memory.base != nil {
        buf.memory.base.destroy()
    }
}

let on_new_connect: @convention(c) (UnsafeMutablePointer<uv_stream_t>, CInt) -> Void = { (server, status) in
    if status < 0 {
        print("New connection error \(uv_strerror(status))")
        // error!
        return
    }
    
    let client = UnsafeMutablePointer<uv_tcp_t>.alloc(sizeof(uv_tcp_t))
    uv_tcp_init(loop, client)
    
    if uv_accept(server, UnsafeMutablePointer<uv_stream_t>(client)) == 0 {
        uv_read_start(UnsafeMutablePointer<uv_stream_t>(client), alloc_buffer, echo_read)
    } else {
        uv_close(UnsafeMutablePointer<uv_handle_t>(client), nil)
    }

}

func main() -> CInt {
    loop = uv_default_loop()

    var server = uv_tcp_t()
    uv_tcp_init(loop, &server)
    
    uv_ip4_addr("0.0.0.0", CInt(DEFAULT_PORT), &addr)
    
    withUnsafePointer(&addr) {
        uv_tcp_bind(&server, UnsafePointer<sockaddr>($0), 0)
    }
    
    withUnsafePointer(&server) {
        let r = uv_listen(UnsafeMutablePointer<uv_stream_t>($0), CInt(DEFAULT_BACKLOG), on_new_connect)
        if r != 0 {
            print("Listen error \(uv_strerror(r))")
        }
    }
    
    return uv_run(loop, UV_RUN_DEFAULT)
}

exit(main())