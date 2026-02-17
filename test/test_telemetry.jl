using Test
using Suindara

@testset "Telemetry Module" begin
    T = Suindara.TelemetryModule

    @testset "TelemetryStore começa vazio" begin
        store = T.TelemetryStore()
        @test isempty(T.get_handlers(store, :request_start))
    end

    @testset "attach registra handler" begin
        store = T.TelemetryStore()
        T.attach!(store, :request_start, data -> nothing)
        @test length(T.get_handlers(store, :request_start)) == 1
    end

    @testset "emit chama todos os handlers do evento" begin
        store = T.TelemetryStore()
        log = []
        T.attach!(store, :request_end, data -> push!(log, data[:status]))
        T.attach!(store, :request_end, data -> push!(log, data[:latency]))

        T.emit(store, :request_end, Dict(:status => 200, :latency => 5.0))
        @test length(log) == 2
        @test 200 in log
        @test 5.0 in log
    end

    @testset "emit com evento sem handlers não explode" begin
        store = T.TelemetryStore()
        T.emit(store, :unregistered, Dict())
        @test true
    end

    @testset "measure_latency retorna tempo em ms" begin
        ms = T.measure_latency() do
            sleep(0.01)
        end
        @test ms >= 5.0
        @test ms < 1000.0
    end

end
