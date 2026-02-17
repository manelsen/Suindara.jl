using Test
using Suindara

@testset "Benchmark Smoke Tests" begin

    # Skip if BenchmarkSuite module is not yet defined/exported
    if isdefined(Suindara, :BenchmarkSuite)
        BS = Suindara.BenchmarkSuite

        @testset "bench_pipeline_throughput roda sem erro" begin
            result = BS.bench_pipeline_throughput(10) # Low N for smoke test
            @test result isa Float64
            @test result >= 0.0
        end

        @testset "bench_json_parse roda sem erro" begin
            result = BS.bench_json_parse(10)
            @test result isa Float64
            @test result >= 0.0
        end

        @testset "bench_route_matching roda sem erro" begin
            result = BS.bench_route_matching(10) # Low N for smoke test
            @test result isa Float64
            @test result >= 0.0
        end

        @testset "format_report retorna string formatada" begin
            results = Dict("pipeline" => 1.5, "json" => 2.3)
            report = BS.format_report(results)
            @test report isa String
            @test contains(report, "pipeline")
            @test contains(report, "1.5")
        end
    else
        @warn "Suindara.BenchmarkSuite not defined, skipping smoke tests"
    end

end
