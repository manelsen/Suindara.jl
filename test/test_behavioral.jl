using Test
using Suindara
using HTTP
using JSON3

@testset "Behavioral Tests" begin

    @testset "Pipeline: plug that throws returns 500" begin
        function exploding_plug(conn::Conn)
            error("Boom!")
        end

        req = HTTP.Request("GET", "/", [], "")
        conn = Conn(req)
        result = run_pipeline(conn, [exploding_plug])

        @test result.status == 500
        @test result.halted
    end

    @testset "Pipeline: halted conn skips remaining plugs" begin
        call_log = String[]

        function plug_a(conn::Conn)
            push!(call_log, "a")
            return halt!(conn, 403, "Forbidden")
        end
        function plug_b(conn::Conn)
            push!(call_log, "b")
            return conn
        end

        req = HTTP.Request("GET", "/", [], "")
        conn = Conn(req)
        result = run_pipeline(conn, [plug_a, plug_b])

        @test result.status == 403
        @test result.halted
        @test call_log == ["a"]  # plug_b never called
    end

    @testset "Router: unmatched route returns 404" begin
        @router EmptyRouter begin
            get("/exists", conn -> resp(conn, 200, "OK"))
        end

        req = HTTP.Request("GET", "/does-not-exist", [], "")
        result = match_and_dispatch(EmptyRouter, req)

        @test result.status == 404
    end

    @testset "Router: wrong HTTP method returns 404" begin
        @router MethodRouter begin
            get("/only-get", conn -> resp(conn, 200, "OK"))
        end

        req = HTTP.Request("POST", "/only-get", [], "")
        result = match_and_dispatch(MethodRouter, req)

        @test result.status == 404
    end

    @testset "Router: handler exception returns 500" begin
        @router CrashRouter begin
            get("/crash", conn -> error("Handler crash!"))
        end

        req = HTTP.Request("GET", "/crash", [], "")
        result = match_and_dispatch(CrashRouter, req)

        @test result.status == 500
        @test result.resp_body == "Internal Server Error"
    end

    @testset "Router: halted conn passed to dispatch is returned as-is" begin
        @router SkipRouter begin
            get("/skip", conn -> resp(conn, 200, "Should not reach"))
        end

        req = HTTP.Request("GET", "/skip", [], "")
        conn = Conn(req)
        halt!(conn, 418, "I'm a teapot")

        result = match_and_dispatch(SkipRouter, conn)
        @test result.status == 418
        @test result.resp_body == "I'm a teapot"
    end

    @testset "render_json — custom status codes" begin
        req = HTTP.Request("GET", "/", [], "")
        conn = Conn(req)

        result = render_json(conn, Dict("created" => true), status=201)
        @test result.status == 201
        @test occursin("application/json", first(h.second for h in result.resp_headers if h.first == "Content-Type"))

        conn2 = Conn(HTTP.Request("GET", "/", [], ""))
        result2 = render_json(conn2, Dict("error" => "bad"), status=422)
        @test result2.status == 422
    end

    @testset "plug_json_parser — invalid JSON returns 400" begin
        req = HTTP.Request("POST", "/", ["Content-Type" => "application/json"], Vector{UInt8}("{bad json}"))
        conn = Conn(req)
        result = plug_json_parser(conn)

        @test result.status == 400
        @test result.halted
        @test result.resp_body == "Invalid JSON body"
    end

    @testset "plug_json_parser — non-JSON content-type is no-op" begin
        req = HTTP.Request("POST", "/", ["Content-Type" => "text/plain"], Vector{UInt8}("hello"))
        conn = Conn(req)
        result = plug_json_parser(conn)

        @test !result.halted
        @test isempty(result.params)
    end

    @testset "Transaction rollback preserves DB state" begin
        Repo.connect(":memory:")
        Repo.execute("CREATE TABLE txn_test (id INTEGER PRIMARY KEY, val TEXT)")
        Repo.execute("INSERT INTO txn_test (val) VALUES (?)", ["original"])

        try
            Repo.transaction() do
                Repo.execute("UPDATE txn_test SET val = ? WHERE id = 1", ["modified"])
                # Verify modification is visible inside transaction
                row = Repo.get_one("txn_test", 1)
                @test row.val == "modified"
                error("Force rollback")
            end
        catch
        end

        # After rollback, original value should be restored
        row = Repo.get_one("txn_test", 1)
        @test row.val == "original"
    end
end
