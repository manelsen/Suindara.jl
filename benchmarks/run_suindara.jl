using Pkg
Pkg.activate(".")
using Suindara
using HTTP
using JSON3

# Define Controller
module BenchController
    using Suindara
    using JSON3
    
    function index(conn::Conn)
        return resp(conn, 200, JSON3.write(Dict("message" => "Hello World")), content_type="application/json")
    end
end

# Define Router
@router BenchRouter begin
    get("/", BenchController.index)
end

# Server Loop
port = 8080
println("Starting Suindara on port $port...")

function handler(req)
    conn = match_and_dispatch(BenchRouter, req)
    return HTTP.Response(conn.status, conn.resp_headers, conn.resp_body)
end

HTTP.serve(handler, "0.0.0.0", port)
