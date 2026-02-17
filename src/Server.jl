module ServerModule

using HTTP
using ..RouterModule
using ..SocketModule
using ..ConnModule

export handle_stream

"""
    handle_request(router::SuindaraRouter, req::HTTP.Request)

Main entry point for the server.
Checks for WebSocket upgrades first. If the path matches a socket route, upgrades the connection.
Otherwise, dispatches to the HTTP router.
"""
function handle_stream(router::SuindaraRouter, stream::HTTP.Stream)
    req = stream.message
    
    # 1. Check for WebSocket Upgrade
    if HTTP.WebSockets.is_upgrade(req)
        path = req.target
         # @info "WebSocket upgrade request" path
        
        if haskey(router.socket_routes, path)
            # @info "WebSocket route found" path
            registry = router.socket_routes[path]
            
            # Perform upgrade using the stream
            try
                HTTP.WebSockets.upgrade(stream) do ws
                    try
                        SocketModule.handle_socket(ws, registry)
                    catch e
                         @error "handle_socket failed" exception=(e, catch_backtrace())
                    end
                end
            catch e
                 @error "HTTP.WebSockets.upgrade failed" exception=(e, catch_backtrace())
                rethrow(e)
            end
            return
        end
    end

    # 2. Standard HTTP Dispatch
    # We need to read the body from the stream to construct a full request for the router
    if !isempty(req.body)
         # Body already present (unlikely in stream mode unless pre-read)
    else
        req.body = read(stream)
    end
    
    conn = match_and_dispatch(router, req)
    response = HTTP.Response(conn.status, conn.resp_headers, conn.resp_body)
    
    # Write response to stream
    HTTP.setstatus(stream, response.status)
    for (k, v) in response.headers
        HTTP.setheader(stream, k => v)
    end
    
    # Check if body is empty or null to avoid attempting to write nothing if that causes issues, 
    # though write usually handles empty arrays fine.
    startwrite(stream)
    write(stream, response.body)
end

end # module
