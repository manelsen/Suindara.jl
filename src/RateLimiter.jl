"""
    module RateLimiterModule

Rate limiting via Token Bucket, por IP do cliente.
"""
module RateLimiterModule

using ..ConnModule
using HTTP

export make_rate_limit_plug, TokenBucket, consume!, available_tokens, get_client_ip

"""
    mutable struct TokenBucket

Token bucket para rate limiting.
"""
mutable struct TokenBucket
    max_tokens::Int
    tokens::Float64
    refill_rate::Float64
    last_refill::Float64

    function TokenBucket(; max_tokens::Int=60, refill_rate::Float64=1.0)
        new(max_tokens, Float64(max_tokens), refill_rate, time())
    end
end

"""
    refill!(bucket) — Recarrega tokens baseado no tempo decorrido.
"""
function refill!(bucket::TokenBucket)
    now = time()
    elapsed = now - bucket.last_refill
    bucket.tokens = min(bucket.max_tokens, bucket.tokens + elapsed * bucket.refill_rate)
    bucket.last_refill = now
end

"""
    available_tokens(bucket) :: Int
"""
function available_tokens(bucket::TokenBucket)::Int
    refill!(bucket)
    return floor(Int, bucket.tokens)
end

"""
    consume!(bucket) :: Bool — Consome 1 token, retorna false se vazio.
"""
function consume!(bucket::TokenBucket)::Bool
    refill!(bucket)
    if bucket.tokens >= 1.0
        bucket.tokens -= 1.0
        return true
    end
    return false
end

"""
    get_client_ip(peer_addr::String) :: String
"""
function get_client_ip(peer_addr::String)::String
    parts = split(peer_addr, ":")
    if length(parts) >= 1
        return String(parts[1])
    end
    return "unknown"
end

"""
    make_rate_limit_plug(; max_requests, window_seconds) :: Function
"""
function make_rate_limit_plug(; max_requests::Int=60, window_seconds::Float64=60.0)::Function
    buckets = Dict{String, TokenBucket}()
    refill_rate = max_requests / window_seconds

    return function(conn::Conn)
        ip = "127.0.0.1"  # default
        for h in conn.request.headers
            if h.first == "X-Forwarded-For" || (h isa Pair && h[1] == "X-Forwarded-For")
                ip = h.second isa String ? h.second : string(h[2])
                break
            end
        end

        if !haskey(buckets, ip)
            buckets[ip] = TokenBucket(max_tokens=max_requests, refill_rate=refill_rate)
        end

        if !consume!(buckets[ip])
            return halt!(conn, 429, "Too Many Requests")
        end

        return conn
    end
end

end # module
