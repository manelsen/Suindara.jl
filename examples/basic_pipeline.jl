using Suindara
using HTTP

# Simple Plugs (Middleware)
function logger(conn::Conn)
    println("Request: $(conn.request.method) $(conn.request.target)")
    return conn
end

function authenticate(conn::Conn)
    # Mock authentication
    auth_header = HTTP.header(conn.request, "Authorization")
    if auth_header == "Bearer suindara-token"
        println("Auth: Success")
        return assign(conn, :user_id, 123)
    else
        println("Auth: Failed")
        return halt!(conn, 401, "Go away!")
    end
end

function hello_action(conn::Conn)
    user_id = get(conn.assigns, :user_id, "Guest")
    return resp(conn, 200, "Hello, User $(user_id)!", content_type="text/plain")
end

# Simulate a request
req = HTTP.Request("GET", "/api/data", ["Authorization" => "Bearer suindara-token"], "")
conn = Conn(req)

# Run the run_pipeline
plugs = [logger, authenticate, hello_action]
final_conn = run_pipeline(conn, plugs)

println("Final Status: $(final_conn.status)")
println("Final Body: $(final_conn.resp_body)")

# Simulate a failed request
bad_req = HTTP.Request("GET", "/api/data", [], "")
bad_conn = Conn(bad_req)
final_bad_conn = run_pipeline(bad_conn, plugs)

println("Bad Request Status: $(final_bad_conn.status)")
println("Bad Request Body: $(final_bad_conn.resp_body)")
