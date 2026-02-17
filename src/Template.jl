"""
    module TemplateModule

Motor de templates HTML simples com interpolação {{var}} e escape por padrão.
{{{var}}} insere sem escape (raw HTML).
"""
module TemplateModule

using ..ConnModule

export render_string, render_file, escape_html, plug_render_html

"""
    escape_html(s::String) :: String

Escapa caracteres HTML perigosos.
"""
function escape_html(s::String)::String
    s = replace(s, "&" => "&amp;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    s = replace(s, "\"" => "&quot;")
    s = replace(s, "'" => "&#39;")
    return s
end

"""
    render_string(template::String, vars::Dict) :: String

Interpola variáveis no template.
- `{{key}}` → escape HTML
- `{{{key}}}` → raw (sem escape)
"""
function render_string(template::String, vars::Dict)::String
    result = template

    # Raw (triple braces) first — prevents double-processing
    for (key, val) in vars
        result = replace(result, "{{{$key}}}" => string(val))
    end

    # Escaped (double braces)
    for (key, val) in vars
        result = replace(result, "{{$key}}" => escape_html(string(val)))
    end

    return result
end

"""
    render_file(filepath::String, vars::Dict) :: String

Lê template de arquivo e interpola variáveis.
"""
function render_file(filepath::String, vars::Dict)::String
    template = read(filepath, String)
    return render_string(template, vars)
end

"""
    plug_render_html(conn::Conn, html::String; status=200) :: Conn

Plug que seta o body como HTML e o Content-Type correto.
"""
function plug_render_html(conn::Conn, html::String; status::Int=200)::Conn
    return resp(conn, status, html, content_type="text/html; charset=utf-8")
end

end # module
