using Suindara

# Controllers
module PageController
    using Suindara
    index(conn::Conn) = resp(conn, 200, "Home Page")
    about(conn::Conn) = resp(conn, 200, "About Suindara")
end

# The "Phoenix" Way
@router MyRouter begin
    get("/", PageController.index)
    get("/about", PageController.about)
end

# Testing the generated router
using HTTP
req = HTTP.Request("GET", "/", [], "")
conn = match_and_dispatch(MyRouter, req)

println("Path: / -> Status: $(conn.status), Body: $(conn.resp_body)")

req_about = HTTP.Request("GET", "/about", [], "")
conn_about = match_and_dispatch(MyRouter, req_about)
println("Path: /about -> Status: $(conn_about.status), Body: $(conn_about.resp_body)")