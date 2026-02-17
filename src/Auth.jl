"""
    module AuthModule

Plugs de autenticação para o pipeline Suindara.
"""
module AuthModule

using ..ConnModule
using HTTP

export make_bearer_plug, extract_bearer_token

"""
    extract_bearer_token(header_value::String) :: Union{String, Nothing}

Extrai o token de um header "Bearer <token>".
"""
function extract_bearer_token(header_value::String)::Union{String, Nothing}
    if startswith(header_value, "Bearer ")
        return header_value[8:end]
    end
    return nothing
end

"""
    make_bearer_plug(verify_fn::Function) :: Function

Factory que cria plug de autenticação Bearer.
"""
function make_bearer_plug(verify_fn::Function)::Function
    return function(conn::Conn)
        auth_header = ""
        for h in conn.request.headers
            if h.first == "Authorization" || (h isa Pair && h[1] == "Authorization")
                auth_header = h.second isa String ? h.second : string(h[2])
                break
            end
        end

        token = extract_bearer_token(auth_header)

        if token === nothing
            return halt!(conn, 401, "Missing Authorization header")
        end

        if !verify_fn(token)
            return halt!(conn, 401, "Invalid token")
        end

        conn = assign(conn, :authenticated, true)
        return conn
    end
end

end # module
