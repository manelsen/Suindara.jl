using Test
using Suindara
using HTTP

@testset "Auth Plugs" begin
    Auth = Suindara.AuthModule

    @testset "extract_bearer_token extrai token" begin
        @test Auth.extract_bearer_token("Bearer abc123") == "abc123"
        @test Auth.extract_bearer_token("Bearer ") == ""
        @test Auth.extract_bearer_token("Basic xyz") === nothing
        @test Auth.extract_bearer_token("") === nothing
    end

    @testset "make_bearer_plug aceita token válido" begin
        verify(token) = token == "secret"
        plug = Auth.make_bearer_plug(verify)

        req = HTTP.Request("GET", "/", ["Authorization" => "Bearer secret"], "")
        conn = Conn(req)
        conn = plug(conn)
        @test conn.halted == false
        @test conn.assigns[:authenticated] == true
    end

    @testset "make_bearer_plug rejeita token inválido" begin
        verify(token) = token == "secret"
        plug = Auth.make_bearer_plug(verify)

        req = HTTP.Request("GET", "/", ["Authorization" => "Bearer wrong"], "")
        conn = Conn(req)
        conn = plug(conn)
        @test conn.halted == true
        @test conn.status == 401
    end

    @testset "make_bearer_plug rejeita sem header" begin
        verify(token) = true
        plug = Auth.make_bearer_plug(verify)

        req = HTTP.Request("GET", "/", [], "")
        conn = Conn(req)
        conn = plug(conn)
        @test conn.halted == true
        @test conn.status == 401
    end

end
