module WebModule

using ..ConnModule
using HTTP
using JSON3

export plug_json_parser, render_json

"""
    plug_json_parser(conn::Conn)
Parses the request body as JSON if the Content-Type is application/json.
Merges the parsed data into `conn.params`.
"""
function plug_json_parser(conn::Conn)
    content_type = HTTP.header(conn.request, "Content-Type")
    
    if startswith(content_type, "application/json") && !isempty(conn.request.body)
        try
            json_body = JSON3.read(conn.request.body, Dict{Symbol, Any})
            merge!(conn.params, json_body)
        catch e
            # In a real framework, we might want to log this or halt
            # For now, we just ignore parsing errors or empty bodies
        end
    end
    
    return conn
end

"""
    render_json(conn::Conn, data::Any; status::Int=200)
Serializes `data` to JSON and sets the response body and content type.
"""
function render_json(conn::Conn, data::Any; status::Int=200)
    json_str = JSON3.write(data)
    return resp(conn, status, json_str, content_type="application/json")
end

end # module
