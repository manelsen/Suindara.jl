"""
    module CSRFModule

Cross-Site Request Forgery protection plug.
Gera token por sessão, valida em requests mutantes (POST/PUT/PATCH/DELETE).
"""
module CSRFModule

using ..ConnModule
using HTTP
using Random

export make_csrf_plug, generate_csrf_token, is_safe_method

const SAFE_METHODS = Set(["GET", "HEAD", "OPTIONS"])

# Armazena tokens por session_id
const _TOKEN_STORE = Dict{String, String}()

function generate_csrf_token()::String
    return bytes2hex(rand(UInt8, 32))
end

function is_safe_method(method::String)::Bool
    return method in SAFE_METHODS
end

function get_or_create_token(session_id::String)::String
    if !haskey(_TOKEN_STORE, session_id)
        _TOKEN_STORE[session_id] = generate_csrf_token()
    end
    return _TOKEN_STORE[session_id]
end

function extract_submitted_token(conn::Conn)::String
    header_token = HTTP.header(conn.request, "X-CSRF-Token", "")
    if !isempty(header_token)
        return header_token
    end
    return get(conn.params, "_csrf_token", "")
end

function make_csrf_plug()::Function
    return function(conn::Conn)
        session_id = get(conn.assigns, :session_id, "anonymous")
        token = get_or_create_token(string(session_id))
        conn = assign(conn, :csrf_token, token)

        if is_safe_method(conn.request.method)
            return conn
        end

        submitted = extract_submitted_token(conn)
        if submitted != token
            return halt!(conn, 403, "Invalid CSRF token")
        end

        return conn
    end
end

end # module
