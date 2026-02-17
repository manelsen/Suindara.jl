using Test
using Suindara
using HTTP

@testset "Test Helpers" begin
    TH = Suindara.TestHelpersModule

    @testset "build_conn cria GET request" begin
        conn = TH.build_conn("GET", "/users")
        @test conn isa Conn
        @test conn.request.method == "GET"
        @test conn.request.target == "/users"
    end

    @testset "build_conn cria POST com JSON body" begin
        conn = TH.build_conn("POST", "/users", json=Dict("name" => "Ana"))
        @test conn.request.method == "POST"
        body_str = String(copy(conn.request.body))
        @test contains(body_str, "Ana")
    end

    @testset "assert_status verifica status do conn" begin
        conn = TH.build_conn("GET", "/")
        conn = resp(conn, 201, "created")
        @test TH.assert_status(conn, 201) == true
        @test TH.assert_status(conn, 200) == false
    end

    @testset "assert_body_contains verifica conteúdo do body" begin
        conn = TH.build_conn("GET", "/")
        conn = resp(conn, 200, "Hello World")
        @test TH.assert_body_contains(conn, "Hello") == true
        @test TH.assert_body_contains(conn, "Bye") == false
    end

    @testset "setup_test_db cria banco in-memory" begin
        TH.setup_test_db()
        Suindara.Repo.execute("CREATE TABLE helpers_test (id INTEGER PRIMARY KEY)")
        @test true
    end

end
