#!/usr/bin/env julia
using Suindara

BS = Suindara.BenchmarkSuite
N = 10_000

println("Running benchmarks with N=$N...")

results = Dict(
    "pipeline" => BS.bench_pipeline_throughput(N),
    "json_parse" => BS.bench_json_parse(N),
    "route_matching" => BS.bench_route_matching(N),
)

println(BS.format_report(results))
