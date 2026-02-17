module SocketModule

using HTTP
using JSON3
using ..ChannelModule
import ..ConnModule: assign

export Socket, handle_socket, assign

"""
    mutable struct Socket

Represents a WebSocket connection.
"""
mutable struct Socket
    ws::HTTP.WebSockets.WebSocket
    assigns::Dict{Symbol, Any}
    topics::Set{String}
    registry::ChannelRegistry
    
    function Socket(ws::HTTP.WebSockets.WebSocket, registry::ChannelRegistry)
        new(ws, Dict{Symbol, Any}(), Set{String}(), registry)
    end
end

"""
    assign(socket::Socket, key::Symbol, value::Any)
"""
function assign(socket::Socket, key::Symbol, value::Any)
    socket.assigns[key] = value
    return socket
end

"""
    handle_socket(ws::HTTP.WebSockets.WebSocket, registry::ChannelRegistry)

Main loop for a WebSocket connection.
Reads JSON messages: `{"topic": "room:1", "event": "new_msg", "payload": {...}, "ref": "1"}`
"""
function handle_socket(ws::HTTP.WebSockets.WebSocket, registry::ChannelRegistry)
    socket = Socket(ws, registry)
    
    try
        for msg in ws
            # Parse message
            data = try
                JSON3.read(msg)
            catch e
                @warn "Invalid JSON received" exception=e
                continue
            end
            
            topic = get(data, "topic", nothing)
            event = get(data, "event", nothing)
            payload = get(data, "payload", nothing)
            ref = get(data, "ref", nothing)
            
            if topic === nothing || event === nothing
                @warn "Missing topic or event"
                continue
            end
            
            # Dispatch to Channel
            response_payload = ChannelModule.dispatch_event(registry, String(topic), Symbol(event), payload)
            
            # If there is a response and a ref, execute callback/reply (simple acknowledgement)
            if ref !== nothing
                response = Dict(
                    "topic" => topic,
                    "event" => "phx_reply", # Phoenix convention
                    "ref" => ref,
                    "payload" => Dict("status" => "ok", "response" => response_payload)
                )
                HTTP.WebSockets.send(ws, JSON3.write(response))
            end
        end
    catch e
        if e isa HTTP.WebSockets.WebSocketError
            # Normal closure
        else
            @error "WebSocket error" exception=e
        end
    end
end

end # module
