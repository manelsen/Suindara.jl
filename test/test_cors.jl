using Test
using Suindara
using HTTP

# --- Helpers: funções puras minúsculas ---
dummy_cors_index(conn) = resp(conn, 200, "index")

@testset "CORS Plug" begin

    @testset "plug_cors adiciona headers padrão" begin
        req = HTTP.Request("GET", "/api/data", [], "")
        conn = Conn(req)
        conn = Suindara.CorsModule.plug_cors(conn)

        @test any(h -> h == ("Access-Control-Allow-Origin" => "*"), conn.resp_headers)
        @test any(h -> h == ("Access-Control-Allow-Methods" => "GET, POST, PUT, PATCH, DELETE, OPTIONS"), conn.resp_headers)
        @test any(h -> h == ("Access-Control-Allow-Headers" => "Content-Type, Authorization"), conn.resp_headers)
        @test conn.halted == false
    end

    @testset "plug_cors halts OPTIONS request com 204" begin
        req = HTTP.Request("OPTIONS", "/api/data", [], "")
        conn = Conn(req)
        conn = Suindara.CorsModule.plug_cors(conn)

        @test conn.status == 204
        @test conn.halted == true
        @test conn.resp_body == ""
    end

    @testset "make_cors_plug com origin customizada" begin
        custom_plug = Suindara.CorsModule.make_cors_plug(
            allow_origin="https://myapp.com",
            allow_methods="GET, POST",
            allow_headers="X-Custom"
        )

        req = HTTP.Request("GET", "/", [], "")
        conn = Conn(req)
        conn = custom_plug(conn)

        @test any(h -> h == ("Access-Control-Allow-Origin" => "https://myapp.com"), conn.resp_headers)
        @test any(h -> h == ("Access-Control-Allow-Methods" => "GET, POST"), conn.resp_headers)
        @test any(h -> h == ("Access-Control-Allow-Headers" => "X-Custom"), conn.resp_headers)
    end

    @testset "make_cors_plug com OPTIONS e origin customizada" begin
        custom_plug = Suindara.CorsModule.make_cors_plug(allow_origin="https://x.com")
        req = HTTP.Request("OPTIONS", "/", [], "")
        conn = Conn(req)
        conn = custom_plug(conn)
        @test conn.halted == true
        @test conn.status == 204
    end

end
