module ConnModule

using HTTP
using JSON3

export Conn, assign, halt!, resp

mutable struct Conn
    request::HTTP.Request
    params::Dict{Symbol, Any}
    assigns::Dict{Symbol, Any}
    status::Int
    resp_body::String
    resp_headers::Vector{Pair{String, String}}
    halted::Bool

    function Conn(req::HTTP.Request)
        new(req, Dict{Symbol, Any}(), Dict{Symbol, Any}(), 200, "", Pair{String, String}[], false)
    end
end

"""
    assign(conn::Conn, key::Symbol, value::Any)
Assigns a value to the connection state, accessible by subsequent plugs.
"""
function assign(conn::Conn, key::Symbol, value::Any)
    conn.assigns[key] = value
    return conn
end

"""
    halt!(conn::Conn, status::Int=401, body::String="Unauthorized")
Stops the pipeline execution and sets the response status and body.
"""
function halt!(conn::Conn, status::Int=401, body::String="Unauthorized")
    conn.status = status
    conn.resp_body = body
    conn.halted = true
    return conn
end

"""
    resp(conn::Conn, status::Int, body::String, content_type::String="text/plain")
Sets the response status, body, and content type.
"""
function resp(conn::Conn, status::Int, body::String; content_type::String="text/plain")
    conn.status = status
    conn.resp_body = body
    push!(conn.resp_headers, "Content-Type" => content_type)
    return conn
end

end # module
