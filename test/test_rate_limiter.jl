using Test
using Suindara
using HTTP

@testset "Rate Limiter" begin
    RL = Suindara.RateLimiterModule

    @testset "TokenBucket começa cheio" begin
        bucket = RL.TokenBucket(max_tokens=5, refill_rate=1.0)
        @test RL.available_tokens(bucket) == 5
    end

    @testset "consume! decrementa tokens" begin
        bucket = RL.TokenBucket(max_tokens=5, refill_rate=1.0)
        @test RL.consume!(bucket) == true
        @test RL.available_tokens(bucket) == 4
    end

    @testset "consume! retorna false quando vazio" begin
        bucket = RL.TokenBucket(max_tokens=1, refill_rate=0.0)
        @test RL.consume!(bucket) == true
        @test RL.consume!(bucket) == false
    end

    @testset "get_client_ip extrai IP" begin
        ip = RL.get_client_ip("192.168.1.1:5000")
        @test ip == "192.168.1.1"
    end

    @testset "make_rate_limit_plug permite requests dentro do limite" begin
        plug = RL.make_rate_limit_plug(max_requests=10, window_seconds=60.0)
        req = HTTP.Request("GET", "/api/data", [], "")
        conn = Conn(req)
        conn = plug(conn)
        @test conn.halted == false
    end

end
