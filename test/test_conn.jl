using Test
using Suindara
using HTTP

@testset "Conn Module Unit Tests" begin
    req = HTTP.Request("GET", "/", [], "")
    conn = Conn(req)

    @testset "Initialization" begin
        @test conn.status == 200
        @test conn.halted == false
        @test isempty(conn.assigns)
        @test conn.resp_body == ""
    end

    @testset "Assigns" begin
        conn = assign(conn, :user_id, 1)
        @test conn.assigns[:user_id] == 1
    end

    @testset "Halt" begin
        conn = halt!(conn, 403, "Forbidden")
        @test conn.status == 403
        @test conn.resp_body == "Forbidden"
        @test conn.halted == true
    end

    @testset "Response" begin
        conn = Conn(req) # reset
        conn = resp(conn, 201, "Created", content_type="application/json")
        @test conn.status == 201
        @test conn.resp_body == "Created"
        @test any(h -> h == ("Content-Type" => "application/json"), conn.resp_headers)
    end
end
