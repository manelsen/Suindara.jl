using Suindara
using HTTP

# 1. Define Controllers (just functions for now)
module UserController
    using Suindara
    function index(conn::Conn)
        return resp(conn, 200, "User Index", content_type="text/plain")
    end
    function show(conn::Conn)
        return resp(conn, 200, "User Profile", content_type="text/plain")
    end
end

# 2. Define Routes
const routes = [
    Route("GET", "/", (conn) -> resp(conn, 200, "Welcome Home")),
    Route("GET", "/users", UserController.index),
    Route("GET", "/profile", UserController.show)
]

# 3. Start Server
function start()
    println("Suindara starting on http://localhost:8080...")
    HTTP.serve(8080) do req::HTTP.Request
        # The core flow: Request -> Match -> Dispatch -> Response
        conn = match_and_dispatch(routes, req)
        
        # Convert Conn back to HTTP.Response
        return HTTP.Response(conn.status, conn.resp_headers, body=conn.resp_body)
    end
end

# To run this, uncomment the line below:
# start()
