using Test
using Suindara

@testset "Channel Module" begin
    Ch = Suindara.ChannelModule

    @testset "ChannelRegistry começa vazio" begin
        registry = Ch.ChannelRegistry()
        @test Ch.registered_topics(registry) |> isempty
    end

    @testset "register_handler registra handler" begin
        registry = Ch.ChannelRegistry()
        handler(msg) = "echo:$msg"
        Ch.register_handler!(registry, "room:lobby", :new_msg, handler)
        @test "room:lobby" in Ch.registered_topics(registry)
    end

    @testset "dispatch_event chama handler correto" begin
        registry = Ch.ChannelRegistry()
        log = []
        handler(msg) = push!(log, "got:$msg")
        Ch.register_handler!(registry, "room:lobby", :new_msg, handler)
        Ch.dispatch_event(registry, "room:lobby", :new_msg, "hello")
        @test length(log) == 1
        @test log[1] == "got:hello"
    end

    @testset "dispatch_event ignora tópico não registrado" begin
        registry = Ch.ChannelRegistry()
        result = Ch.dispatch_event(registry, "room:unknown", :event, "data")
        @test result === nothing
    end

    @testset "dispatch_event ignora evento não registrado" begin
        registry = Ch.ChannelRegistry()
        handler(msg) = msg
        Ch.register_handler!(registry, "room:lobby", :new_msg, handler)
        result = Ch.dispatch_event(registry, "room:lobby", :unknown_event, "data")
        @test result === nothing
    end

    @testset "parse_topic_pattern extrai padrão" begin
        @test Ch.parse_topic_pattern("room:lobby") == ("room", "lobby")
        @test Ch.parse_topic_pattern("chat:*") == ("chat", "*")
        @test Ch.parse_topic_pattern("simple") == ("simple", "")
    end

    @testset "topic_matches com wildcard" begin
        @test Ch.topic_matches("room:lobby", "room:lobby") == true
        @test Ch.topic_matches("room:*", "room:lobby") == true
        @test Ch.topic_matches("room:*", "room:123") == true
        @test Ch.topic_matches("room:*", "chat:lobby") == false
        @test Ch.topic_matches("room:lobby", "room:other") == false
    end

    @testset "múltiplos handlers para mesmo tópico" begin
        registry = Ch.ChannelRegistry()
        results = []
        Ch.register_handler!(registry, "room:lobby", :join, msg -> push!(results, "join:$msg"))
        Ch.register_handler!(registry, "room:lobby", :leave, msg -> push!(results, "leave:$msg"))

        Ch.dispatch_event(registry, "room:lobby", :join, "Alice")
        Ch.dispatch_event(registry, "room:lobby", :leave, "Bob")

        @test length(results) == 2
        @test results[1] == "join:Alice"
        @test results[2] == "leave:Bob"
    end

end
