"""
    module ErrorHandlerModule

Formatação de erros para desenvolvimento e produção.
Dev: mostra exceção, backtrace, request info.
Prod: mostra mensagem genérica.
"""
module ErrorHandlerModule

export is_dev_mode, format_error, format_error_dev, format_error_prod

"""
    is_dev_mode() :: Bool

Retorna true se SUINDARA_ENV != "prod". Default: dev mode.
"""
function is_dev_mode()::Bool
    env = get(ENV, "SUINDARA_ENV", "dev")
    return env != "prod"
end

"""
    format_error_dev(e::Exception, bt) :: String

Formata erro para modo dev com detalhes completos.
"""
function format_error_dev(e::Exception, bt)::String
    io = IOBuffer()
    println(io, "=== SUINDARA DEBUG ERROR ===")
    println(io, "Exception Type: $(typeof(e))")
    println(io, "Message: $(sprint(showerror, e))")
    println(io, "")
    println(io, "--- Backtrace ---")
    for frame in stacktrace(bt)
        println(io, "  $(frame)")
    end
    println(io, "=== END DEBUG ===")
    return String(take!(io))
end

"""
    format_error_prod(e::Exception, bt) :: String

Formata erro para modo prod. NÃO vaza informações internas.
"""
function format_error_prod(::Exception, bt)::String
    return "Internal Server Error"
end

"""
    format_error(e::Exception, bt) :: String

Despacha para dev ou prod baseado no modo.
"""
function format_error(e::Exception, bt)::String
    if is_dev_mode()
        return format_error_dev(e, bt)
    else
        return format_error_prod(e, bt)
    end
end

end # module
