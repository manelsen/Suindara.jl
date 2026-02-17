"""
    module StaticFileModule

Plug para servir arquivos estáticos de um diretório local.
Inclui proteção contra path traversal e detecção de MIME type.
"""
module StaticFileModule

using ..ConnModule
using HTTP

export make_static_plug, guess_mime_type, sanitize_path

const MIME_TYPES = Dict(
    ".html" => "text/html",
    ".css"  => "text/css",
    ".js"   => "application/javascript",
    ".json" => "application/json",
    ".png"  => "image/png",
    ".jpg"  => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif"  => "image/gif",
    ".svg"  => "image/svg+xml",
    ".ico"  => "image/x-icon",
    ".woff" => "font/woff",
    ".woff2"=> "font/woff2",
    ".txt"  => "text/plain",
)

"""
    guess_mime_type(filename::String) :: String

Retorna o MIME type baseado na extensão do arquivo.
"""
function guess_mime_type(filename::String)::String
    for (ext, mime) in MIME_TYPES
        if endswith(filename, ext)
            return mime
        end
    end
    return "application/octet-stream"
end

"""
    sanitize_path(relative_path::String) :: Union{String, Nothing}

Valida que o path relativo não contém path traversal.
"""
function sanitize_path(relative_path::String)::Union{String, Nothing}
    decoded = HTTP.URIs.unescapeuri(relative_path)
    if contains(decoded, "..")
        return nothing
    end
    return decoded
end

"""
    make_static_plug(directory::String, url_prefix::String) :: Function

Factory que retorna um plug para servir arquivos estáticos.
"""
function make_static_plug(directory::String, url_prefix::String)::Function
    return function(conn::Conn)
        path = conn.request.target

        if !startswith(path, url_prefix)
            return conn
        end

        relative = path[length(url_prefix)+1:end]
        if startswith(relative, "/")
            relative = relative[2:end]
        end

        clean_path = sanitize_path(relative)
        if clean_path === nothing
            return halt!(conn, 400, "Bad Request: invalid path")
        end

        full_path = joinpath(directory, clean_path)

        if !isfile(full_path)
            return halt!(conn, 404, "File not found")
        end

        content = read(full_path, String)
        mime = guess_mime_type(clean_path)
        conn = resp(conn, 200, content, content_type=mime)
        conn.halted = true
        return conn
    end
end

end # module
