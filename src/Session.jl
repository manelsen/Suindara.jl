"""
    module SessionModule

Gerenciamento de sessões in-memory com suporte a cookies.
"""
module SessionModule

using ..ConnModule
using HTTP
using Random

export MemorySessionStore, make_session_plug, session_get, session_put!, session_delete!,
       generate_session_id, extract_session_cookie

const SESSION_COOKIE_NAME = "_session"

"""
    generate_session_id() :: String

Gera um ID de sessão aleatório de 32 bytes hexadecimais.
"""
function generate_session_id()::String
    return bytes2hex(rand(UInt8, 32))
end

"""
    mutable struct MemorySessionStore

Armazena sessões em memória via Dict.
"""
mutable struct MemorySessionStore
    data::Dict{String, Dict{Symbol, Any}}

    function MemorySessionStore()
        new(Dict{String, Dict{Symbol, Any}}())
    end
end

function session_get(store::MemorySessionStore, session_id::String, key::Symbol)
    if !haskey(store.data, session_id)
        return nothing
    end
    return get(store.data[session_id], key, nothing)
end

function session_put!(store::MemorySessionStore, session_id::String, key::Symbol, value)
    if !haskey(store.data, session_id)
        store.data[session_id] = Dict{Symbol, Any}()
    end
    store.data[session_id][key] = value
end

function session_delete!(store::MemorySessionStore, session_id::String, key::Symbol)
    if haskey(store.data, session_id)
        delete!(store.data[session_id], key)
    end
end

"""
    extract_session_cookie(cookie_header::String) :: Union{String, Nothing}

Extrai o valor do cookie de sessão.
"""
function extract_session_cookie(cookie_header::String)::Union{String, Nothing}
    for part in split(cookie_header, "; ")
        kv = split(strip(part), "=", limit=2)
        if length(kv) == 2 && kv[1] == SESSION_COOKIE_NAME
            return String(kv[2])
        end
    end
    return nothing
end

"""
    make_session_plug(store::MemorySessionStore) :: Function
"""
function make_session_plug(store::MemorySessionStore)::Function
    return function(conn::Conn)
        cookie_header = ""
        for h in conn.request.headers
            key = h isa Pair ? h.first : h[1]
            if key == "Cookie"
                cookie_header = h isa Pair ? h.second : h[2]
                cookie_header = cookie_header isa String ? cookie_header : string(cookie_header)
                break
            end
        end

        existing_id = extract_session_cookie(cookie_header)

        session_id = if existing_id !== nothing && haskey(store.data, existing_id)
            existing_id
        else
            new_id = generate_session_id()
            store.data[new_id] = Dict{Symbol, Any}()
            push!(conn.resp_headers, "Set-Cookie" => "$(SESSION_COOKIE_NAME)=$(new_id); Path=/; HttpOnly")
            new_id
        end

        conn = assign(conn, :session_id, session_id)
        conn = assign(conn, :session_store, store)
        return conn
    end
end

end # module
