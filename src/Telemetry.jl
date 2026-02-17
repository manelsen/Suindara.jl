"""
    module TelemetryModule

Sistema de telemetria baseado em eventos para instrumentação do pipeline.
"""
module TelemetryModule

export TelemetryStore, attach!, emit, get_handlers, measure_latency

"""
    mutable struct TelemetryStore — Registra handlers por evento.
"""
mutable struct TelemetryStore
    handlers::Dict{Symbol, Vector{Function}}

    function TelemetryStore()
        new(Dict{Symbol, Vector{Function}}())
    end
end

"""
    get_handlers(store, event) :: Vector{Function}
"""
function get_handlers(store::TelemetryStore, event::Symbol)::Vector{Function}
    return get(store.handlers, event, Function[])
end

"""
    attach!(store, event, handler) — Registra handler para evento.
"""
function attach!(store::TelemetryStore, event::Symbol, handler::Function)
    if !haskey(store.handlers, event)
        store.handlers[event] = Function[]
    end
    push!(store.handlers[event], handler)
end

"""
    emit(store, event, data) — Despacha evento para todos handlers.
"""
function emit(store::TelemetryStore, event::Symbol, data::Dict)
    for handler in get_handlers(store, event)
        try
            handler(data)
        catch e
            @warn "Telemetry handler error" event=event exception=e
        end
    end
end

"""
    measure_latency(f::Function) :: Float64

Executa f() e retorna tempo em milissegundos.
"""
function measure_latency(f::Function)::Float64
    t0 = time()
    f()
    t1 = time()
    return (t1 - t0) * 1000.0
end

end # module
