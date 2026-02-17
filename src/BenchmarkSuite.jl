"""
    module BenchmarkSuite

Suite de benchmarks internos para medir performance das operações core.
Cada função retorna tempo médio por operação em milissegundos.
"""
module BenchmarkSuite

using ..ConnModule
using ..PipelineModule
using ..RouterModule
using ..WebModule
using ..FormParserModule
using HTTP
using JSON3
using Random

export bench_pipeline_throughput, bench_json_parse, bench_route_matching, format_report

"""
    bench_pipeline_throughput(n::Int) :: Float64

Mede ms/operação para processar n requests pelo pipeline.
"""
function bench_pipeline_throughput(n::Int)::Float64
    noop(c) = c
    plugs = [noop, noop, noop]
    req = HTTP.Request("GET", "/", [], "")

    # Warmup
    for _ in 1:10
        conn = Conn(req)
        run_pipeline(conn, plugs)
    end
    GC.gc()

    t0 = time()
    for _ in 1:n
        conn = Conn(req)
        run_pipeline(conn, plugs)
    end
    elapsed_ms = (time() - t0) * 1000.0
    return elapsed_ms / n
end

"""
    bench_json_parse(n::Int) :: Float64

Mede ms/operação para parsear n JSON bodies.
"""
function bench_json_parse(n::Int)::Float64
    body = JSON3.write(Dict("name" => "test", "value" => 42, "active" => true))
    req = HTTP.Request("POST", "/", ["Content-Type" => "application/json"], body)

    # Warmup
    for _ in 1:10
        conn = Conn(req)
        plug_json_parser(conn)
    end
    GC.gc()

    t0 = time()
    for _ in 1:n
        conn = Conn(req)
        plug_json_parser(conn)
    end
    elapsed_ms = (time() - t0) * 1000.0
    return elapsed_ms / n
end

"""
    bench_route_matching(n::Int) :: Float64

Mede ms/operação para matching de n requests contra um router.
"""
function bench_route_matching(n::Int)::Float64
    handler(c) = resp(c, 200, "ok")

    @router BenchRouter begin
        get("/", handler)
        get("/users", handler)
        get("/users/:id", handler)
        post("/users", handler)
        get("/users/:id/posts/:post_id", handler)
    end

    paths = ["/", "/users", "/users/42", "/users/1/posts/7"]

    # Warmup
    for path in paths
        req = HTTP.Request("GET", path, [], "")
        match_and_dispatch(BenchRouter, req)
    end
    GC.gc()

    t0 = time()
    for i in 1:n
        path = paths[mod1(i, length(paths))]
        req = HTTP.Request("GET", path, [], "")
        match_and_dispatch(BenchRouter, req)
    end
    elapsed_ms = (time() - t0) * 1000.0
    return elapsed_ms / n
end

"""
    format_report(results::Dict) :: String

Formata resultados de benchmark para impressão.
"""
function format_report(results::Dict)::String
    io = IOBuffer()
    println(io, "=== Suindara.jl Benchmark Report ===")
    println(io, "")
    for (name, ms) in sort(collect(results), by=first)
        println(io, "  $(name): $(round(ms, digits=4)) ms/op")
    end
    println(io, "")
    println(io, "====================================")
    return String(take!(io))
end

end # module
