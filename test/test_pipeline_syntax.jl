using Test
using Suindara
using Suindara: status, put_header, json, text, html
using HTTP
using JSON3

@testset "Pipeline Syntax" begin
    # Mock Request
    req = HTTP.Request("GET", "/")
    conn = Conn(req)

    @testset "status() helper" begin
        c = Conn(req)
        new_conn = c |> status(418)
        @test new_conn.status == 418
    end

    @testset "put_header() helper" begin
        c = Conn(req)
        new_conn = c |> put_header("X-Test", "Passed")
        @test ("X-Test" => "Passed") in new_conn.resp_headers
    end

    @testset "json() helper" begin
        c = Conn(req)
        data = Dict("foo" => "bar")
        new_conn = c |> status(201) |> json(data)
        
        @test new_conn.status == 201
        @test new_conn.resp_body == JSON3.write(data)
        @test ("Content-Type" => "application/json") in new_conn.resp_headers
    end

    @testset "text() helper" begin
        c = Conn(req)
        new_conn = c |> status(404) |> text("Not Found")
        
        @test new_conn.status == 404
        @test new_conn.resp_body == "Not Found"
        @test ("Content-Type" => "text/plain") in new_conn.resp_headers
    end

    @testset "html() helper" begin
        c = Conn(req)
        new_conn = c |> html("<h1>Hi</h1>")
        
        @test new_conn.status == 200 # Default kept if not changed
        @test new_conn.resp_body == "<h1>Hi</h1>"
        @test ("Content-Type" => "text/html") in new_conn.resp_headers
    end
end
