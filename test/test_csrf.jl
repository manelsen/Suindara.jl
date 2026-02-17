using Test
using Suindara
using HTTP

@testset "CSRF Protection" begin
    CSRF = Suindara.CSRFModule

    @testset "generate_csrf_token retorna string >= 32 chars" begin
        token = CSRF.generate_csrf_token()
        @test token isa String
        @test length(token) >= 32
    end

    @testset "is_safe_method identifica métodos seguros" begin
        @test CSRF.is_safe_method("GET") == true
        @test CSRF.is_safe_method("HEAD") == true
        @test CSRF.is_safe_method("OPTIONS") == true
        @test CSRF.is_safe_method("POST") == false
        @test CSRF.is_safe_method("PUT") == false
        @test CSRF.is_safe_method("DELETE") == false
    end

    @testset "plug_csrf permite GET sem token" begin
        plug = CSRF.make_csrf_plug()
        req = HTTP.Request("GET", "/page", [], "")
        conn = Conn(req)
        conn = assign(conn, :session_id, "test_csrf_get")
        conn = plug(conn)
        @test conn.halted == false
        @test haskey(conn.assigns, :csrf_token)
    end

    @testset "plug_csrf bloqueia POST sem token" begin
        plug = CSRF.make_csrf_plug()
        req = HTTP.Request("POST", "/submit", [], "")
        conn = Conn(req)
        conn = assign(conn, :session_id, "test_csrf_post")
        conn = plug(conn)
        @test conn.halted == true
        @test conn.status == 403
    end

    @testset "plug_csrf aceita POST com token válido no header" begin
        plug = CSRF.make_csrf_plug()

        # GET para obter token
        req1 = HTTP.Request("GET", "/form", [], "")
        conn1 = Conn(req1)
        conn1 = assign(conn1, :session_id, "csrf_valid_sess")
        conn1 = plug(conn1)
        token = conn1.assigns[:csrf_token]

        # POST com token
        req2 = HTTP.Request("POST", "/submit", ["X-CSRF-Token" => token], "")
        conn2 = Conn(req2)
        conn2 = assign(conn2, :session_id, "csrf_valid_sess")
        conn2 = plug(conn2)
        @test conn2.halted == false
    end

end
