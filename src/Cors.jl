"""
    module CorsModule

Fornece plugs de CORS (Cross-Origin Resource Sharing) para o pipeline Suindara.
Inclui um plug padrão permissivo e uma factory para configuração customizada.
"""
module CorsModule

using ..ConnModule
using HTTP

export plug_cors, make_cors_plug

const DEFAULT_ORIGIN = "*"
const DEFAULT_METHODS = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
const DEFAULT_HEADERS = "Content-Type, Authorization"

"""
    add_cors_headers!(conn, origin, methods, headers) :: Conn

Adiciona os 3 headers CORS ao conn.
"""
function add_cors_headers!(conn::Conn, origin::String, methods::String, headers::String)::Conn
    push!(conn.resp_headers, "Access-Control-Allow-Origin" => origin)
    push!(conn.resp_headers, "Access-Control-Allow-Methods" => methods)
    push!(conn.resp_headers, "Access-Control-Allow-Headers" => headers)
    return conn
end

"""
    is_preflight(conn) :: Bool

Retorna true se a request é um preflight OPTIONS.
"""
function is_preflight(conn::Conn)::Bool
    return conn.request.method == "OPTIONS"
end

"""
    plug_cors(conn::Conn) :: Conn

Plug CORS com configuração padrão permissiva (origin="*").
Halts com 204 em requests OPTIONS (preflight).
"""
function plug_cors(conn::Conn)::Conn
    conn = add_cors_headers!(conn, DEFAULT_ORIGIN, DEFAULT_METHODS, DEFAULT_HEADERS)
    if is_preflight(conn)
        return halt!(conn, 204, "")
    end
    return conn
end

"""
    make_cors_plug(; allow_origin, allow_methods, allow_headers) :: Function

Factory que retorna um plug CORS customizado.
"""
function make_cors_plug(;
    allow_origin::String = DEFAULT_ORIGIN,
    allow_methods::String = DEFAULT_METHODS,
    allow_headers::String = DEFAULT_HEADERS
)::Function
    return function(conn::Conn)
        conn = add_cors_headers!(conn, allow_origin, allow_methods, allow_headers)
        if is_preflight(conn)
            return halt!(conn, 204, "")
        end
        return conn
    end
end

end # module
