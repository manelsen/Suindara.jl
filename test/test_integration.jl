using Test
using Suindara
using HTTP

@testset "Integration: Phoenix-style Flow" begin
    # Plugs
    function set_format(conn::Conn)
        return assign(conn, :format, "json")
    end

    function check_api_key(conn::Conn)
        key = HTTP.header(conn.request, "X-API-KEY")
        if key == "secret"
            return conn
        else
            return halt!(conn, 401, "Invalid Key")
        end
    end

    function mock_action(conn::Conn)
        format = conn.assigns[:format]
        return resp(conn, 200, "{\"status\": \"ok\", \"format\": \"$format\"}", content_type="application/json")
    end

    pipeline_steps = [set_format, check_api_key, mock_action]

    @testset "Successful Request" begin
        req = HTTP.Request("GET", "/api", ["X-API-KEY" => "secret"], "")
        conn = Conn(req)
        res = run_pipeline(conn, pipeline_steps)
        
        @test res.status == 200
        @test occursin("json", res.resp_body)
        @test !res.halted
    end

    @testset "Failed Request (Halted)" begin
        req = HTTP.Request("GET", "/api", ["X-API-KEY" => "wrong"], "")
        conn = Conn(req)
        res = run_pipeline(conn, pipeline_steps)
        
        @test res.status == 401
        @test res.resp_body == "Invalid Key"
        @test res.halted
    end
end
