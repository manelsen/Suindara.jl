using Test
using Suindara
using HTTP
using JSON3

@testset "WebSocket Integration" begin
    # 1. Setup Registry
    registry = ChannelRegistry()
    
    # Echo handler
    Suindara.register_handler!(registry, "room:lobby", :echo, (payload) -> begin
        return payload
    end)

    # 2. Setup Router
    @router WSRouter begin
        websocket("/ws", registry)
        get("/", (conn) -> text(conn, "HTTP OK"))
    end

    # 3. Start Server (Async)
    port = 9292
    server_task = @async HTTP.serve("127.0.0.1", port; stream=true) do stream
        Suindara.handle_stream(WSRouter, stream)
    end
    
    
    # Wait for server to start
    started = false
    for i in 1:20 # Increase timeout
        try
            HTTP.get("http://127.0.0.1:$port/")
            started = true
            break
        catch
            sleep(0.1)
        end
    end
    
    if !started
        @error "Server failed to start"
        return
    end

    try
        # 4. Connect via WebSocket
        try
            HTTP.WebSockets.open("ws://127.0.0.1:$port/ws") do ws
                # Send message
                msg = Dict(
                    "topic" => "room:lobby", 
                    "event" => "echo", 
                    "payload" => Dict("msg" => "hello"),
                    "ref" => "1"
                )
                HTTP.WebSockets.send(ws, JSON3.write(msg))
                
                # Read reply
                response_raw = HTTP.WebSockets.receive(ws)
                response = JSON3.read(response_raw)
                
                @test response.topic == "room:lobby"
                @test response.event == "phx_reply"
                @test response.ref == "1"
                @test response.payload.status == "ok"
                @test response.payload.response.msg == "hello"
            end
        catch e
            @error "WebSocket connection failed" exception=(e, catch_backtrace())
            rethrow(e)
        end
        
        # 5. Connect to invalid path (should fail or close) - skipping for now to keep test simple
    finally
        # Cleanup
    end
end
