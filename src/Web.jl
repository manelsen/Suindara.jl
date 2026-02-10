"""
    module WebModule

Provides web-specific plugs and utilities, such as JSON parsing and rendering.
"""
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
            # Use Dict{String, Any} to avoid Symbol interning DoS
            json_body = JSON3.read(conn.request.body, Dict{String, Any})
            merge!(conn.params, json_body)
        catch e
            # Invalid JSON should stop the pipeline immediately
            return halt!(conn, 400, "Invalid JSON body")
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
