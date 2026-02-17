# KANBAN — FASE 3: Real-Time & API DX (v0.7 → v0.8)

> **REGRAS PARA A IA EXECUTORA:**
>
> 1. **TDD RIGOROSO**: NUNCA escreva código de produção antes do teste. Ordem: RED → GREEN → REFACTOR.
> 2. **FUNÇÕES PURAS E MINÚSCULAS**: Cada função faz UMA coisa só. Máximo 15 linhas.
> 3. **RODAR TESTES**: Após cada GREEN ou REFACTOR: `julia --project=. test/runtests.jl`
> 4. **PRÉ-REQUISITO**: Fases 1 e 2 devem estar 100% completas.
> 5. **NÃO PULE ETAPAS**.

---

## Tarefa 3.1: WebSocket Channels

**Objetivo**: Suporte a WebSockets via HTTP.jl, com abstração de Channels (tópicos).

**Arquivos envolvidos**:
- `src/Channel.jl` (NOVO)
- `src/Suindara.jl` (EDITAR)
- `test/test_channel.jl` (NOVO)
- `test/runtests.jl` (EDITAR)

### RED

- [ ] Criar `test/test_channel.jl`:

```julia
using Test
using Suindara

@testset "Channel Module" begin
    Ch = Suindara.ChannelModule

    @testset "ChannelRegistry começa vazio" begin
        registry = Ch.ChannelRegistry()
        @test Ch.registered_topics(registry) |> isempty
    end

    @testset "register_handler registra um handler para um tópico" begin
        registry = Ch.ChannelRegistry()
        handler(msg) = "echo:$msg"
        Ch.register_handler!(registry, "room:lobby", :new_msg, handler)

        topics = Ch.registered_topics(registry)
        @test "room:lobby" in topics
    end

    @testset "dispatch_event chama handler correto" begin
        registry = Ch.ChannelRegistry()
        log = []
        handler(msg) = push!(log, "got:$msg")
        Ch.register_handler!(registry, "room:lobby", :new_msg, handler)

        Ch.dispatch_event(registry, "room:lobby", :new_msg, "hello")
        @test length(log) == 1
        @test log[1] == "got:hello"
    end

    @testset "dispatch_event ignora tópico não registrado" begin
        registry = Ch.ChannelRegistry()
        # Não deve explodir
        result = Ch.dispatch_event(registry, "room:unknown", :event, "data")
        @test result === nothing
    end

    @testset "dispatch_event ignora evento não registrado" begin
        registry = Ch.ChannelRegistry()
        handler(msg) = msg
        Ch.register_handler!(registry, "room:lobby", :new_msg, handler)
        result = Ch.dispatch_event(registry, "room:lobby", :unknown_event, "data")
        @test result === nothing
    end

    @testset "parse_topic_pattern extrai padrão" begin
        @test Ch.parse_topic_pattern("room:lobby") == ("room", "lobby")
        @test Ch.parse_topic_pattern("chat:*") == ("chat", "*")
        @test Ch.parse_topic_pattern("simple") == ("simple", "")
    end

    @testset "topic_matches verifica matching com wildcard" begin
        @test Ch.topic_matches("room:lobby", "room:lobby") == true
        @test Ch.topic_matches("room:*", "room:lobby") == true
        @test Ch.topic_matches("room:*", "room:123") == true
        @test Ch.topic_matches("room:*", "chat:lobby") == false
        @test Ch.topic_matches("room:lobby", "room:other") == false
    end

    @testset "múltiplos handlers para mesmo tópico" begin
        registry = Ch.ChannelRegistry()
        results = []
        Ch.register_handler!(registry, "room:lobby", :join, msg -> push!(results, "join:$msg"))
        Ch.register_handler!(registry, "room:lobby", :leave, msg -> push!(results, "leave:$msg"))

        Ch.dispatch_event(registry, "room:lobby", :join, "Alice")
        Ch.dispatch_event(registry, "room:lobby", :leave, "Bob")

        @test length(results) == 2
        @test results[1] == "join:Alice"
        @test results[2] == "leave:Bob"
    end

end
```

- [ ] Adicionar `include("test_channel.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM. RED ✅

### GREEN

- [ ] Criar `src/Channel.jl`:

```julia
"""
    module ChannelModule

Abstração de Channels (tópicos) para comunicação real-time via WebSockets.
Inspirado no Phoenix.Channel.

Este módulo implementa a lógica de registro e dispatch de eventos.
A integração com HTTP.jl WebSockets é feita separadamente no servidor.
"""
module ChannelModule

export ChannelRegistry, register_handler!, dispatch_event, registered_topics,
       parse_topic_pattern, topic_matches

"""
    mutable struct ChannelRegistry

Registra handlers organizados por tópico e evento.
Estrutura: Dict[topic => Dict[event => handler_function]]
"""
mutable struct ChannelRegistry
    handlers::Dict{String, Dict{Symbol, Function}}

    function ChannelRegistry()
        new(Dict{String, Dict{Symbol, Function}}())
    end
end

"""
    registered_topics(registry) :: Vector{String}

Retorna lista de tópicos registrados. Função pura.
"""
function registered_topics(registry::ChannelRegistry)::Vector{String}
    return collect(keys(registry.handlers))
end

"""
    register_handler!(registry, topic, event, handler)

Registra um handler para um tópico+evento específico.
"""
function register_handler!(registry::ChannelRegistry, topic::String, event::Symbol, handler::Function)
    if !haskey(registry.handlers, topic)
        registry.handlers[topic] = Dict{Symbol, Function}()
    end
    registry.handlers[topic][event] = handler
end

"""
    dispatch_event(registry, topic, event, payload) :: Any

Encontra e executa o handler para o tópico+evento.
Retorna nothing se não há handler registrado.
"""
function dispatch_event(registry::ChannelRegistry, topic::String, event::Symbol, payload)
    # Busca exata primeiro
    if haskey(registry.handlers, topic) && haskey(registry.handlers[topic], event)
        return registry.handlers[topic][event](payload)
    end

    # Busca com wildcard
    for (pattern, events) in registry.handlers
        if topic_matches(pattern, topic) && haskey(events, event)
            return events[event](payload)
        end
    end

    return nothing
end

"""
    parse_topic_pattern(topic::String) :: Tuple{String, String}

Separa "namespace:subtopic" em seus componentes. Função pura.
"""
function parse_topic_pattern(topic::String)::Tuple{String, String}
    parts = split(topic, ":", limit=2)
    if length(parts) == 2
        return (String(parts[1]), String(parts[2]))
    end
    return (String(parts[1]), "")
end

"""
    topic_matches(pattern::String, topic::String) :: Bool

Verifica se um tópico corresponde a um padrão (suporta wildcard *). Função pura.
"""
function topic_matches(pattern::String, topic::String)::Bool
    if pattern == topic
        return true
    end

    pat_ns, pat_sub = parse_topic_pattern(pattern)
    top_ns, _ = parse_topic_pattern(topic)

    return pat_ns == top_ns && pat_sub == "*"
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - `include("Channel.jl")` após ErrorHandler.jl
  - `using .ChannelModule`
  - `export ChannelRegistry, register_handler!, dispatch_event`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Tarefa 3.2: OpenAPI/Swagger Auto-Gerado

**Objetivo**: Gerar spec OpenAPI 3.0 automaticamente a partir das rotas do router.

**Arquivos envolvidos**:
- `src/OpenAPI.jl` (NOVO)
- `src/Suindara.jl` (EDITAR)
- `test/test_openapi.jl` (NOVO)
- `test/runtests.jl` (EDITAR)

### RED

- [ ] Criar `test/test_openapi.jl`:

```julia
using Test
using Suindara
using JSON3

# Helpers
dummy_handler(conn) = resp(conn, 200, "ok")

@testset "OpenAPI Module" begin
    OA = Suindara.OpenAPIModule

    @testset "route_to_openapi_path converte :id para {id}" begin
        @test OA.route_to_openapi_path("/users/:id") == "/users/{id}"
        @test OA.route_to_openapi_path("/api/v1/items/:item_id/reviews/:review_id") == "/api/v1/items/{item_id}/reviews/{review_id}"
        @test OA.route_to_openapi_path("/health") == "/health"
    end

    @testset "extract_path_params extrai parâmetros" begin
        params = OA.extract_path_params("/users/:id/posts/:post_id")
        @test length(params) == 2
        @test params[1] == "id"
        @test params[2] == "post_id"
    end

    @testset "extract_path_params sem parâmetros" begin
        params = OA.extract_path_params("/health")
        @test isempty(params)
    end

    @testset "generate_spec retorna Dict válido OpenAPI" begin
        @router OpenAPITestRouter begin
            get("/users", dummy_handler)
            get("/users/:id", dummy_handler)
            post("/users", dummy_handler)
            delete("/users/:id", dummy_handler)
        end

        spec = OA.generate_spec(OpenAPITestRouter, title="TestAPI", version="1.0.0")

        @test spec["openapi"] == "3.0.0"
        @test spec["info"]["title"] == "TestAPI"
        @test spec["info"]["version"] == "1.0.0"
        @test haskey(spec["paths"], "/users")
        @test haskey(spec["paths"], "/users/{id}")
        @test haskey(spec["paths"]["/users"], "get")
        @test haskey(spec["paths"]["/users"], "post")
        @test haskey(spec["paths"]["/users/{id}"], "get")
        @test haskey(spec["paths"]["/users/{id}"], "delete")
    end

    @testset "generate_spec path params incluídos" begin
        @router ParamAPIRouter begin
            get("/items/:id", dummy_handler)
        end

        spec = OA.generate_spec(ParamAPIRouter)
        path_item = spec["paths"]["/items/{id}"]
        get_op = path_item["get"]
        @test haskey(get_op, "parameters")
        @test length(get_op["parameters"]) == 1
        @test get_op["parameters"][1]["name"] == "id"
        @test get_op["parameters"][1]["in"] == "path"
    end

    @testset "spec_to_json retorna JSON válido" begin
        @router JSONTestRouter begin
            get("/ping", dummy_handler)
        end
        spec = OA.generate_spec(JSONTestRouter)
        json_str = OA.spec_to_json(spec)
        @test json_str isa String
        parsed = JSON3.read(json_str)
        @test parsed["openapi"] == "3.0.0"
    end

end
```

- [ ] Adicionar `include("test_openapi.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM. RED ✅

### GREEN

- [ ] Criar `src/OpenAPI.jl`:

```julia
"""
    module OpenAPIModule

Geração automática de especificação OpenAPI 3.0 a partir das rotas registradas.
"""
module OpenAPIModule

using ..RouterModule
using JSON3

export generate_spec, spec_to_json, route_to_openapi_path, extract_path_params

"""
    route_to_openapi_path(path::String) :: String

Converte `:param` para `{param}` no path. Função pura.
"""
function route_to_openapi_path(path::String)::String
    return replace(path, r":([a-zA-Z_][a-zA-Z0-9_]*)" => s"{\1}")
end

"""
    extract_path_params(path::String) :: Vector{String}

Extrai nomes de parâmetros do path (prefixados com :). Função pura.
"""
function extract_path_params(path::String)::Vector{String}
    params = String[]
    for m in eachmatch(r":([a-zA-Z_][a-zA-Z0-9_]*)", path)
        push!(params, m.captures[1])
    end
    return params
end

"""
    build_param_object(name::String) :: Dict

Cria um objeto parameter OpenAPI para path param. Função pura.
"""
function build_param_object(name::String)::Dict
    return Dict(
        "name" => name,
        "in" => "path",
        "required" => true,
        "schema" => Dict("type" => "string")
    )
end

"""
    generate_spec(router::SuindaraRouter; title, version, description) :: Dict

Gera a especificação OpenAPI 3.0 como Dict a partir de um router.
"""
function generate_spec(router::SuindaraRouter;
    title::String="Suindara API",
    version::String="0.1.0",
    description::String="Auto-generated by Suindara.jl"
)::Dict
    paths = Dict{String, Any}()

    for route in router.routes
        openapi_path = route_to_openapi_path(route.path_template)
        method = lowercase(route.method)
        params = extract_path_params(route.path_template)

        if !haskey(paths, openapi_path)
            paths[openapi_path] = Dict{String, Any}()
        end

        operation = Dict{String, Any}(
            "summary" => "$(route.method) $(route.path_template)",
            "responses" => Dict(
                "200" => Dict("description" => "Successful response")
            )
        )

        if !isempty(params)
            operation["parameters"] = [build_param_object(p) for p in params]
        end

        paths[openapi_path][method] = operation
    end

    return Dict(
        "openapi" => "3.0.0",
        "info" => Dict(
            "title" => title,
            "version" => version,
            "description" => description
        ),
        "paths" => paths
    )
end

"""
    spec_to_json(spec::Dict) :: String

Serializa a spec para JSON. Função pura.
"""
function spec_to_json(spec::Dict)::String
    return JSON3.write(spec)
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - `include("OpenAPI.jl")` após Channel.jl
  - `using .OpenAPIModule`
  - `export generate_spec, spec_to_json`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Tarefa 3.3: Auth Plugs Built-In (Bearer Token)

**Arquivos**: `src/Auth.jl` (NOVO), `test/test_auth.jl` (NOVO)

### RED

- [ ] Criar `test/test_auth.jl`:

```julia
using Test
using Suindara
using HTTP

@testset "Auth Plugs" begin
    Auth = Suindara.AuthModule

    @testset "extract_bearer_token extrai token do header" begin
        @test Auth.extract_bearer_token("Bearer abc123") == "abc123"
        @test Auth.extract_bearer_token("Bearer ") == ""
        @test Auth.extract_bearer_token("Basic xyz") === nothing
        @test Auth.extract_bearer_token("") === nothing
    end

    @testset "make_bearer_plug aceita token válido" begin
        verify(token) = token == "secret"
        plug = Auth.make_bearer_plug(verify)

        req = HTTP.Request("GET", "/", ["Authorization" => "Bearer secret"], "")
        conn = Conn(req)
        conn = plug(conn)
        @test conn.halted == false
        @test conn.assigns[:authenticated] == true
    end

    @testset "make_bearer_plug rejeita token inválido" begin
        verify(token) = token == "secret"
        plug = Auth.make_bearer_plug(verify)

        req = HTTP.Request("GET", "/", ["Authorization" => "Bearer wrong"], "")
        conn = Conn(req)
        conn = plug(conn)
        @test conn.halted == true
        @test conn.status == 401
    end

    @testset "make_bearer_plug rejeita sem header" begin
        verify(token) = true
        plug = Auth.make_bearer_plug(verify)

        req = HTTP.Request("GET", "/", [], "")
        conn = Conn(req)
        conn = plug(conn)
        @test conn.halted == true
        @test conn.status == 401
    end

end
```

- [ ] Adicionar ao `test/runtests.jl`. Rodar → FALHAM. RED ✅

### GREEN

- [ ] Criar `src/Auth.jl`:

```julia
"""
    module AuthModule

Plugs de autenticação para o pipeline Suindara.
"""
module AuthModule

using ..ConnModule
using HTTP

export make_bearer_plug, extract_bearer_token

"""
    extract_bearer_token(header_value::String) :: Union{String, Nothing}

Extrai o token de um header "Bearer <token>". Função pura.
"""
function extract_bearer_token(header_value::String)::Union{String, Nothing}
    if startswith(header_value, "Bearer ")
        return header_value[8:end]
    end
    return nothing
end

"""
    make_bearer_plug(verify_fn::Function) :: Function

Factory que cria plug de autenticação Bearer.
`verify_fn(token::String) :: Bool` — retorna true se token é válido.
"""
function make_bearer_plug(verify_fn::Function)::Function
    return function(conn::Conn)::Conn
        auth_header = HTTP.header(conn.request, "Authorization", "")
        token = extract_bearer_token(auth_header)

        if token === nothing
            return halt!(conn, 401, "Missing Authorization header")
        end

        if !verify_fn(token)
            return halt!(conn, 401, "Invalid token")
        end

        conn = assign(conn, :authenticated, true)
        return conn
    end
end

end # module
```

- [ ] Editar `src/Suindara.jl`: include, using, export.
- [ ] Rodar testes. GREEN ✅ → DONE ✅

---

## Tarefa 3.4: Rate Limiting Plug

**Arquivos**: `src/RateLimiter.jl` (NOVO), `test/test_rate_limiter.jl` (NOVO)

### RED

- [ ] Criar `test/test_rate_limiter.jl`:

```julia
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

    @testset "get_client_ip extrai IP de request" begin
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
```

- [ ] Adicionar ao `test/runtests.jl`. Rodar → FALHAM. RED ✅

### GREEN

- [ ] Criar `src/RateLimiter.jl`:

```julia
"""
    module RateLimiterModule

Rate limiting via Token Bucket, por IP do cliente.
"""
module RateLimiterModule

using ..ConnModule
using HTTP

export make_rate_limit_plug, TokenBucket, consume!, available_tokens, get_client_ip

mutable struct TokenBucket
    max_tokens::Int
    tokens::Float64
    refill_rate::Float64  # tokens por segundo
    last_refill::Float64  # timestamp

    function TokenBucket(; max_tokens::Int=60, refill_rate::Float64=1.0)
        new(max_tokens, Float64(max_tokens), refill_rate, time())
    end
end

function refill!(bucket::TokenBucket)
    now = time()
    elapsed = now - bucket.last_refill
    bucket.tokens = min(bucket.max_tokens, bucket.tokens + elapsed * bucket.refill_rate)
    bucket.last_refill = now
end

function available_tokens(bucket::TokenBucket)::Int
    refill!(bucket)
    return floor(Int, bucket.tokens)
end

function consume!(bucket::TokenBucket)::Bool
    refill!(bucket)
    if bucket.tokens >= 1.0
        bucket.tokens -= 1.0
        return true
    end
    return false
end

function get_client_ip(peer_addr::String)::String
    parts = split(peer_addr, ":")
    if length(parts) >= 1
        return String(parts[1])
    end
    return "unknown"
end

function make_rate_limit_plug(; max_requests::Int=60, window_seconds::Float64=60.0)::Function
    buckets = Dict{String, TokenBucket}()
    refill_rate = max_requests / window_seconds

    return function(conn::Conn)::Conn
        ip = get_client_ip(get(Dict(conn.request.headers), "X-Forwarded-For", "127.0.0.1"))

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
```

- [ ] Editar `src/Suindara.jl`: include, using, export.
- [ ] Rodar testes. GREEN ✅ → DONE ✅

---

## Tarefa 3.5: Telemetria (Hooks Pré/Pós Pipeline)

**Arquivos**: `src/Telemetry.jl` (NOVO), `test/test_telemetry.jl` (NOVO)

### RED

- [ ] Criar `test/test_telemetry.jl`:

```julia
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
            sleep(0.01)  # 10ms
        end
        @test ms >= 5.0  # pelo menos 5ms (tolerância)
        @test ms < 1000.0  # menos de 1 segundo
    end

end
```

- [ ] Adicionar ao `test/runtests.jl`. Rodar → FALHAM. RED ✅

### GREEN

- [ ] Criar `src/Telemetry.jl`:

```julia
"""
    module TelemetryModule

Sistema de telemetria baseado em eventos para instrumentação do pipeline.
"""
module TelemetryModule

export TelemetryStore, attach!, emit, get_handlers, measure_latency

mutable struct TelemetryStore
    handlers::Dict{Symbol, Vector{Function}}

    function TelemetryStore()
        new(Dict{Symbol, Vector{Function}}())
    end
end

function get_handlers(store::TelemetryStore, event::Symbol)::Vector{Function}
    return get(store.handlers, event, Function[])
end

function attach!(store::TelemetryStore, event::Symbol, handler::Function)
    if !haskey(store.handlers, event)
        store.handlers[event] = Function[]
    end
    push!(store.handlers[event], handler)
end

function emit(store::TelemetryStore, event::Symbol, data::Dict)
    for handler in get_handlers(store, event)
        try
            handler(data)
        catch e
            @warn "Telemetry handler error" event=event exception=e
        end
    end
end

"""
    measure_latency(f::Function) :: Float64

Executa f() e retorna o tempo decorrido em milissegundos.
"""
function measure_latency(f::Function)::Float64
    t0 = time()
    f()
    t1 = time()
    return (t1 - t0) * 1000.0
end

end # module
```

- [ ] Editar `src/Suindara.jl`: include, using, export.
- [ ] Rodar testes. GREEN ✅ → DONE ✅

---

## Checklist Final da Fase 3

- [ ] Rodar `julia --project=. test/runtests.jl` — TODOS os testes passam
- [ ] Atualizar `Project.toml` version para `0.7.0`
- [ ] Commitar: `git add . && git commit -m "v0.7.0: Phase 3 — Real-Time & API DX (Channels, OpenAPI, Auth, RateLimiter, Telemetry)"`
