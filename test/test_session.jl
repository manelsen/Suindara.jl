using Test
using Suindara
using HTTP

@testset "Session Module" begin
    S = Suindara.SessionModule

    @testset "generate_session_id retorna string longa" begin
        id = S.generate_session_id()
        @test id isa String
        @test length(id) >= 32
    end

    @testset "generate_session_id produz valores únicos" begin
        @test S.generate_session_id() != S.generate_session_id()
    end

    @testset "SessionStore: get/put/delete" begin
        store = S.MemorySessionStore()
        S.session_put!(store, "abc", :user_id, 42)
        @test S.session_get(store, "abc", :user_id) == 42
        @test S.session_get(store, "abc", :missing) === nothing

        S.session_delete!(store, "abc", :user_id)
        @test S.session_get(store, "abc", :user_id) === nothing
    end

    @testset "SessionStore: sessão inexistente retorna nothing" begin
        store = S.MemorySessionStore()
        @test S.session_get(store, "nonexistent", :key) === nothing
    end

    @testset "extract_session_cookie extrai cookie" begin
        @test S.extract_session_cookie("_session=abc123; other=val") == "abc123"
        @test S.extract_session_cookie("other=val") === nothing
        @test S.extract_session_cookie("") === nothing
    end

    @testset "make_session_plug atribui session_id e store" begin
        store = S.MemorySessionStore()
        plug = S.make_session_plug(store)
        req = HTTP.Request("GET", "/", [], "")
        conn = Conn(req)
        conn = plug(conn)
        @test haskey(conn.assigns, :session_id)
        @test conn.assigns[:session_id] isa String
    end

    @testset "make_session_plug reutiliza session de cookie" begin
        store = S.MemorySessionStore()
        plug = S.make_session_plug(store)
        S.session_put!(store, "existing_id", :user, "Ana")

        req = HTTP.Request("GET", "/", ["Cookie" => "_session=existing_id"], "")
        conn = Conn(req)
        conn = plug(conn)
        @test conn.assigns[:session_id] == "existing_id"
    end

end
