using Test
using Suindara
using HTTP
using JSON3

@testset "Web Ecosystem Tests" begin

    @testset "JSON Parser Plug" begin
        body = JSON3.write(Dict("foo" => "bar", "num" => 42))
        req = HTTP.Request("POST", "/api", ["Content-Type" => "application/json"], body)
        conn = Conn(req)
        
        # This plug doesn't exist yet
        conn = Suindara.plug_json_parser(conn)
        
        @test conn.params["foo"] == "bar"
        @test conn.params["num"] == 42
    end
    
    @testset "Controller Helper: json" begin
        req = HTTP.Request("GET", "/")
        conn = Conn(req)
        
        # Helper to return JSON response easily
        # This helper doesn't exist yet
        conn = Suindara.render_json(conn, Dict("ok" => true))
        
        @test conn.status == 200
        @test conn.resp_body == "{\"ok\":true}"
        @test any(h -> h == ("Content-Type" => "application/json"), conn.resp_headers)
    end
end
