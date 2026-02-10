using Test
using Suindara
using HTTP

@testset "Pipeline Module Unit Tests" begin
    req = HTTP.Request("GET", "/", [], "")
    
    @testset "Sequential Execution" begin
        conn = Conn(req)
        step1(c) = assign(c, :s1, true)
        step2(c) = assign(c, :s2, true)
        
        final_conn = run_pipeline(conn, [step1, step2])
        @test final_conn.assigns[:s1] == true
        @test final_conn.assigns[:s2] == true
    end

    @testset "Halting Logic" begin
        conn = Conn(req)
        stop_step(c) = halt!(c, 400, "Stop")
        never_step(c) = assign(c, :should_not_exist, true)
        
        final_conn = run_pipeline(conn, [stop_step, never_step])
        @test final_conn.status == 400
        @test final_conn.halted == true
        @test !haskey(final_conn.assigns, :should_not_exist)
    end
end
