"""
    module FormParserModule

Parseia bodies de requests com Content-Type:
- application/x-www-form-urlencoded
Merge resultado em conn.params.
"""
module FormParserModule

using ..ConnModule
using HTTP

export plug_form_parser, parse_urlencoded

"""
    decode_plus(s::String) :: String

Substitui '+' por espaço (convenção de form encoding).
"""
function decode_plus(s::String)::String
    return replace(s, '+' => ' ')
end

"""
    parse_urlencoded(body::String) :: Dict{String, Any}

Parseia uma string URL-encoded para Dict.
"""
function parse_urlencoded(body::String)::Dict{String, Any}
    result = Dict{String, Any}()
    if isempty(body)
        return result
    end
    for pair in split(body, '&')
        parts = split(pair, '=', limit=2)
        if length(parts) == 2
            key = HTTP.URIs.unescapeuri(decode_plus(String(parts[1])))
            value = HTTP.URIs.unescapeuri(decode_plus(String(parts[2])))
            result[key] = value
        elseif length(parts) == 1 && !isempty(parts[1])
            key = HTTP.URIs.unescapeuri(decode_plus(String(parts[1])))
            result[key] = ""
        end
    end
    return result
end

"""
    is_form_urlencoded(conn::Conn) :: Bool

Verifica se o Content-Type é application/x-www-form-urlencoded.
"""
function is_form_urlencoded(conn::Conn)::Bool
    for h in conn.request.headers
        if lowercase(h.first) == "content-type" || lowercase(string(h[1])) == "content-type"
            val = h.second isa String ? h.second : string(h[2])
            return startswith(val, "application/x-www-form-urlencoded")
        end
    end
    return false
end

"""
    plug_form_parser(conn::Conn) :: Conn

Plug que parseia form-urlencoded body e merge em conn.params.
"""
function plug_form_parser(conn::Conn)::Conn
    if !is_form_urlencoded(conn)
        return conn
    end

    body_str = String(copy(conn.request.body))
    if isempty(body_str)
        return conn
    end

    parsed = parse_urlencoded(body_str)
    merge!(conn.params, parsed)
    return conn
end

end # module
