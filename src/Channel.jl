"""
    module ChannelModule

Abstração de Channels (tópicos) para comunicação real-time via WebSockets.
Inspirado no Phoenix.Channel. Implementa registro e dispatch de eventos.
"""
module ChannelModule

export ChannelRegistry, register_handler!, dispatch_event, registered_topics,
       parse_topic_pattern, topic_matches

"""
    mutable struct ChannelRegistry

Registra handlers por tópico e evento.
"""
mutable struct ChannelRegistry
    handlers::Dict{String, Dict{Symbol, Function}}

    function ChannelRegistry()
        new(Dict{String, Dict{Symbol, Function}}())
    end
end

"""
    registered_topics(registry) :: Vector{String}

Retorna lista de tópicos registrados.
"""
function registered_topics(registry::ChannelRegistry)::Vector{String}
    return collect(keys(registry.handlers))
end

"""
    register_handler!(registry, topic, event, handler)

Registra um handler para um tópico+evento.
"""
function register_handler!(registry::ChannelRegistry, topic::String, event::Symbol, handler::Function)
    if !haskey(registry.handlers, topic)
        registry.handlers[topic] = Dict{Symbol, Function}()
    end
    registry.handlers[topic][event] = handler
end

"""
    dispatch_event(registry, topic, event, payload) :: Any

Encontra e executa o handler. Retorna nothing se não registrado.
"""
function dispatch_event(registry::ChannelRegistry, topic::String, event::Symbol, payload)
    if haskey(registry.handlers, topic) && haskey(registry.handlers[topic], event)
        return registry.handlers[topic][event](payload)
    end

    for (pattern, events) in registry.handlers
        if topic_matches(pattern, topic) && haskey(events, event)
            return events[event](payload)
        end
    end

    return nothing
end

"""
    parse_topic_pattern(topic::String) :: Tuple{String, String}

Separa "namespace:subtopic" em componentes.
"""
function parse_topic_pattern(topic::String)::Tuple{String, String}
    parts = split(topic, ":", limit=2)
    if length(parts) == 2
        return (String(parts[1]), String(parts[2]))
    end
    return (String(parts[1]), "")
end

"""
    topic_matches(pattern::String, topic::String) :: Bool

Verifica se tópico corresponde a padrão (suporta wildcard *).
"""
function topic_matches(pattern::String, topic::String)::Bool
    if pattern == topic
        return true
    end
    pat_ns, pat_sub = parse_topic_pattern(pattern)
    top_ns, _ = parse_topic_pattern(topic)
    return pat_ns == top_ns && pat_sub == "*"
end

end # module
