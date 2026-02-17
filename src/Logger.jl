"""
    module LoggerModule

Plugs de logging estruturado para o pipeline Suindara.
Adiciona request ID único e formata logs com método, path, status e latência.
"""
module LoggerModule

using ..ConnModule
using HTTP
using UUIDs

export plug_request_id, format_log_line, generate_request_id

"""
    generate_request_id() :: String

Gera um UUID v4 como string.
"""
function generate_request_id()::String
    return string(uuid4())
end

"""
    extract_existing_request_id(conn) :: Union{String, Nothing}

Extrai o header X-Request-ID da request, ou retorna nothing.
"""
function extract_existing_request_id(conn::Conn)::Union{String, Nothing}
    for h in conn.request.headers
        if h.first == "X-Request-ID" || h[1] == "X-Request-ID"
            return h.second isa String ? h.second : string(h[2])
        end
    end
    return nothing
end

"""
    plug_request_id(conn::Conn) :: Conn

Plug que atribui ou preserva X-Request-ID.
"""
function plug_request_id(conn::Conn)::Conn
    existing = extract_existing_request_id(conn)
    req_id = existing !== nothing ? existing : generate_request_id()

    conn = assign(conn, :request_id, req_id)
    push!(conn.resp_headers, "X-Request-ID" => req_id)
    return conn
end

"""
    format_log_line(request_id, method, path, status, latency_ms) :: String

Formata uma linha de log estruturada. Função pura.
"""
function format_log_line(request_id::String, method::String, path::String, status::Int, latency_ms::Float64)::String
    return "[$(request_id)] $(method) $(path) → $(status) ($(latency_ms)ms)"
end

end # module
