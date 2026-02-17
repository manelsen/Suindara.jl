using Test
using Suindara
using HTTP

@testset "Logger Module" begin

    @testset "generate_request_id retorna UUID-like string" begin
        id = Suindara.LoggerModule.generate_request_id()
        @test id isa String
        @test length(id) >= 8
    end

    @testset "generate_request_id retorna valores únicos" begin
        id1 = Suindara.LoggerModule.generate_request_id()
        id2 = Suindara.LoggerModule.generate_request_id()
        @test id1 != id2
    end

    @testset "plug_request_id atribui ID no assigns" begin
        req = HTTP.Request("GET", "/test", [], "")
        conn = Conn(req)
        conn = Suindara.LoggerModule.plug_request_id(conn)
        @test haskey(conn.assigns, :request_id)
        @test conn.assigns[:request_id] isa String
    end

    @testset "plug_request_id preserva X-Request-ID existente" begin
        req = HTTP.Request("GET", "/test", ["X-Request-ID" => "my-custom-id"], "")
        conn = Conn(req)
        conn = Suindara.LoggerModule.plug_request_id(conn)
        @test conn.assigns[:request_id] == "my-custom-id"
    end

    @testset "plug_request_id adiciona header na resposta" begin
        req = HTTP.Request("GET", "/test", [], "")
        conn = Conn(req)
        conn = Suindara.LoggerModule.plug_request_id(conn)
        @test any(h -> h.first == "X-Request-ID", conn.resp_headers)
    end

    @testset "format_log_line retorna string formatada" begin
        line = Suindara.LoggerModule.format_log_line("abc123", "GET", "/users", 200, 12.5)
        @test contains(line, "abc123")
        @test contains(line, "GET")
        @test contains(line, "/users")
        @test contains(line, "200")
        @test contains(line, "12.5")
    end

end
