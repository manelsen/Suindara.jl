"""
    module HotReloadModule

Integração opcional com Revise.jl para recarregamento automático de código.
Se Revise.jl não estiver instalado, todas as funções são no-ops seguros.
"""
module HotReloadModule

export revise_available, start_watching, watched_paths

"""
    revise_available() :: Bool

Retorna `true` se o pacote Revise.jl está carregado no ambiente atual.
"""
function revise_available()::Bool
    return isdefined(Main, :Revise)
end

"""
    start_watching() :: Symbol

Inicia o tracking de arquivos com Revise.jl.
Retorna :watching se Revise disponível, :no_revise caso contrário.
"""
function start_watching()::Symbol
    if !revise_available()
        return :no_revise
    end
    try
        Main.Revise.revise()
        return :watching
    catch e
        @warn "HotReload: falha ao iniciar Revise" exception = e
        return :error
    end
end

"""
    watched_paths() :: Vector{String}

Retorna a lista de caminhos monitorados por Revise, ou vetor vazio.
"""
function watched_paths()::Vector{String}
    if !revise_available()
        return String[]
    end
    try
        return collect(keys(Main.Revise.watched_files))
    catch
        return String[]
    end
end

end # module
