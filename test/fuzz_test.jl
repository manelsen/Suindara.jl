using Test
using Suindara
using HTTP
using Random

@testset "Security Fuzzing Tests" begin
    
    # Define a simple router for fuzzing
    @router FuzzRouter begin
        get("/safe", conn -> resp(conn, 200, "Safe"))
        post("/data/:id", conn -> resp(conn, 201, "Created $(conn.params[:id])"))
    end

    function random_string(len=10)
        return randstring("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_+-=[]{}|;':,./<>?", len)
    end

    @testset "Router Fuzzing" begin
        # Hammer the router with 10,000 random paths
        # Goal: NO unhandled exceptions. All should result in 200, 404, or 500 (handled).
        for _ in 1:10000
            path = "/" * random_string(rand(1:50))
            method = rand(["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"])
            
            req = HTTP.Request(method, path)
            
            try
                conn = match_and_dispatch(FuzzRouter, req)
                @test conn.status in [200, 201, 404, 405, 500]
            catch e
                @error "Router CRASHED on input" path method exception=(e, catch_backtrace())
                @test false # Fail the test if we crash
            end
        end
    end

    @testset "JSON Parser Fuzzing" begin
        # Hammer the JSON parser with garbage
        for _ in 1:5000
            # Generate random garbage bytes
            garbage = random_string(rand(1:1000))
            
            req = HTTP.Request("POST", "/api", ["Content-Type" => "application/json"], garbage)
            conn = Conn(req)
            
            try
                conn = plug_json_parser(conn)
                # Should be halted (400) or passed through (if empty/valid by luck)
                # CRITICAL: It should NOT throw an exception up the stack
                if conn.halted
                    @test conn.status == 400
                end
            catch e
                @error "JSON Parser CRASHED on input" garbage exception=(e, catch_backtrace())
                @test false
            end
        end
    end
end
