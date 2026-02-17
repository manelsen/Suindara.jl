# KANBAN — FASE 4: Full-Stack & Ecossistema (v1.0)

> **REGRAS PARA A IA EXECUTORA:**
>
> 1. **TDD RIGOROSO**: RED → GREEN → REFACTOR. Sem exceção.
> 2. **FUNÇÕES PURAS E MINÚSCULAS**: Máximo 15 linhas por função.
> 3. **RODAR TESTES**: `julia --project=. test/runtests.jl` após cada GREEN/REFACTOR.
> 4. **PRÉ-REQUISITO**: Fases 1, 2 e 3 completas.

---

## Tarefa 4.1: Template Engine (HTML)

**Objetivo**: Motor de templates HTML simples com interpolação de variáveis e includes parciais.

**Arquivos**: `src/Template.jl` (NOVO), `test/test_template.jl` (NOVO)

### RED

- [ ] Criar `test/test_template.jl`:

```julia
using Test
using Suindara

@testset "Template Engine" begin
    T = Suindara.TemplateModule

    @testset "render_string interpola variáveis" begin
        result = T.render_string("Hello, {{name}}!", Dict("name" => "Julia"))
        @test result == "Hello, Julia!"
    end

    @testset "render_string sem variáveis retorna original" begin
        result = T.render_string("Static text", Dict())
        @test result == "Static text"
    end

    @testset "render_string escape HTML por padrão" begin
        result = T.render_string("{{content}}", Dict("content" => "<script>alert('xss')</script>"))
        @test !contains(result, "<script>")
        @test contains(result, "&lt;script&gt;")
    end

    @testset "render_string com {{{raw}}} não escapa" begin
        result = T.render_string("{{{content}}}", Dict("content" => "<b>bold</b>"))
        @test result == "<b>bold</b>"
    end

    @testset "render_string múltiplas variáveis" begin
        template = "{{greeting}}, {{name}}! Age: {{age}}"
        result = T.render_string(template, Dict("greeting" => "Hi", "name" => "Ana", "age" => "30"))
        @test result == "Hi, Ana! Age: 30"
    end

    @testset "escape_html escapa caracteres perigosos" begin
        @test T.escape_html("<b>test</b>") == "&lt;b&gt;test&lt;/b&gt;"
        @test T.escape_html("a & b") == "a &amp; b"
        @test T.escape_html("\"quotes\"") == "&quot;quotes&quot;"
    end

    @testset "render_file lê template de arquivo" begin
        tmpdir = mktempdir()
        write(joinpath(tmpdir, "hello.html"), "<h1>{{title}}</h1>")

        result = T.render_file(joinpath(tmpdir, "hello.html"), Dict("title" => "Welcome"))
        @test result == "<h1>Welcome</h1>"

        rm(tmpdir, recursive=true)
    end

    @testset "plug_render_html seta Content-Type e body" begin
        conn = Suindara.TestHelpersModule.build_conn("GET", "/")
        conn = T.plug_render_html(conn, "<h1>Hi</h1>")
        @test conn.resp_body == "<h1>Hi</h1>"
        @test any(h -> h == ("Content-Type" => "text/html; charset=utf-8"), conn.resp_headers)
    end

end
```

- [ ] Adicionar ao `test/runtests.jl`. Rodar → FALHAM. RED ✅

### GREEN

- [ ] Criar `src/Template.jl`:

```julia
"""
    module TemplateModule

Motor de templates HTML simples com interpolação {{var}} e escape por padrão.
{{{var}}} insere sem escape (raw HTML).
"""
module TemplateModule

using ..ConnModule

export render_string, render_file, escape_html, plug_render_html

"""
    escape_html(s::String) :: String

Escapa caracteres HTML perigosos. Função pura.
"""
function escape_html(s::String)::String
    s = replace(s, "&" => "&amp;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    s = replace(s, "\"" => "&quot;")
    s = replace(s, "'" => "&#39;")
    return s
end

"""
    render_string(template::String, vars::Dict) :: String

Interpola variáveis no template.
- `{{key}}` → escape HTML
- `{{{key}}}` → raw (sem escape)
"""
function render_string(template::String, vars::Dict)::String
    result = template

    # Raw (triple braces) first — prevents double-processing
    for (key, val) in vars
        result = replace(result, "{{{$key}}}" => string(val))
    end

    # Escaped (double braces)
    for (key, val) in vars
        result = replace(result, "{{$key}}" => escape_html(string(val)))
    end

    return result
end

"""
    render_file(filepath::String, vars::Dict) :: String

Lê template de arquivo e interpola variáveis.
"""
function render_file(filepath::String, vars::Dict)::String
    template = read(filepath, String)
    return render_string(template, vars)
end

"""
    plug_render_html(conn::Conn, html::String; status=200) :: Conn

Plug que seta o body como HTML e o Content-Type correto.
"""
function plug_render_html(conn::Conn, html::String; status::Int=200)::Conn
    push!(conn.resp_headers, "Content-Type" => "text/html; charset=utf-8")
    return resp(conn, status, html)
end

end # module
```

- [ ] Editar `src/Suindara.jl`: include, using, export.
- [ ] Rodar testes. GREEN ✅ → DONE ✅

---

## Tarefa 4.2: Session Management

**Arquivos**: `src/Session.jl` (NOVO), `test/test_session.jl` (NOVO)

### RED

- [ ] Criar `test/test_session.jl`:

```julia
using Test
using Suindara
using HTTP

@testset "Session Module" begin
    S = Suindara.SessionModule

    @testset "generate_session_id retorna string longa" begin
        id = S.generate_session_id()
        @test id isa String
        @test length(id) >= 32
    end

    @testset "generate_session_id produz valores únicos" begin
        @test S.generate_session_id() != S.generate_session_id()
    end

    @testset "SessionStore: get/put/delete" begin
        store = S.MemorySessionStore()
        S.session_put!(store, "abc", :user_id, 42)
        @test S.session_get(store, "abc", :user_id) == 42
        @test S.session_get(store, "abc", :missing) === nothing

        S.session_delete!(store, "abc", :user_id)
        @test S.session_get(store, "abc", :user_id) === nothing
    end

    @testset "SessionStore: sessão inexistente retorna nothing" begin
        store = S.MemorySessionStore()
        @test S.session_get(store, "nonexistent", :key) === nothing
    end

    @testset "extract_session_cookie extrai cookie" begin
        @test S.extract_session_cookie("_session=abc123; other=val") == "abc123"
        @test S.extract_session_cookie("other=val") === nothing
        @test S.extract_session_cookie("") === nothing
    end

    @testset "make_session_plug atribui session_id e store" begin
        store = S.MemorySessionStore()
        plug = S.make_session_plug(store)

        req = HTTP.Request("GET", "/", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test haskey(conn.assigns, :session_id)
        @test conn.assigns[:session_id] isa String
    end

    @testset "make_session_plug reutiliza session de cookie" begin
        store = S.MemorySessionStore()
        plug = S.make_session_plug(store)
        S.session_put!(store, "existing_id", :user, "Ana")

        req = HTTP.Request("GET", "/", ["Cookie" => "_session=existing_id"], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.assigns[:session_id] == "existing_id"
    end

end
```

- [ ] Adicionar ao `test/runtests.jl`. Rodar → RED ✅

### GREEN

- [ ] Criar `src/Session.jl`:

```julia
"""
    module SessionModule

Gerenciamento de sessões in-memory com suporte a cookies.
"""
module SessionModule

using ..ConnModule
using HTTP
using Random

export MemorySessionStore, make_session_plug, session_get, session_put!, session_delete!,
       generate_session_id, extract_session_cookie

const SESSION_COOKIE_NAME = "_session"

"""
    generate_session_id() :: String

Gera um ID de sessão aleatório de 32 bytes hexadecimais.
"""
function generate_session_id()::String
    return bytes2hex(rand(UInt8, 32))
end

"""
    mutable struct MemorySessionStore

Armazena sessões em memória via Dict. NÃO persiste entre restarts.
"""
mutable struct MemorySessionStore
    data::Dict{String, Dict{Symbol, Any}}

    function MemorySessionStore()
        new(Dict{String, Dict{Symbol, Any}}())
    end
end

function session_get(store::MemorySessionStore, session_id::String, key::Symbol)
    if !haskey(store.data, session_id)
        return nothing
    end
    return get(store.data[session_id], key, nothing)
end

function session_put!(store::MemorySessionStore, session_id::String, key::Symbol, value)
    if !haskey(store.data, session_id)
        store.data[session_id] = Dict{Symbol, Any}()
    end
    store.data[session_id][key] = value
end

function session_delete!(store::MemorySessionStore, session_id::String, key::Symbol)
    if haskey(store.data, session_id)
        delete!(store.data[session_id], key)
    end
end

"""
    extract_session_cookie(cookie_header::String) :: Union{String, Nothing}

Extrai o valor do cookie de sessão. Função pura.
"""
function extract_session_cookie(cookie_header::String)::Union{String, Nothing}
    for part in split(cookie_header, "; ")
        kv = split(strip(part), "=", limit=2)
        if length(kv) == 2 && kv[1] == SESSION_COOKIE_NAME
            return String(kv[2])
        end
    end
    return nothing
end

"""
    make_session_plug(store::MemorySessionStore) :: Function

Factory que cria plug de sessão. Lê cookie ou cria nova sessão.
"""
function make_session_plug(store::MemorySessionStore)::Function
    return function(conn::Conn)::Conn
        cookie_header = HTTP.header(conn.request, "Cookie", "")
        existing_id = extract_session_cookie(cookie_header)

        session_id = if existing_id !== nothing && haskey(store.data, existing_id)
            existing_id
        else
            new_id = generate_session_id()
            store.data[new_id] = Dict{Symbol, Any}()
            push!(conn.resp_headers, "Set-Cookie" => "$(SESSION_COOKIE_NAME)=$(new_id); Path=/; HttpOnly")
            new_id
        end

        conn = assign(conn, :session_id, session_id)
        conn = assign(conn, :session_store, store)
        return conn
    end
end

end # module
```

- [ ] Editar `src/Suindara.jl`: include, using, export.
- [ ] Rodar testes. GREEN ✅ → DONE ✅

---

## Tarefa 4.3: CSRF Protection Plug

**Arquivos**: `src/CSRF.jl` (NOVO), `test/test_csrf.jl` (NOVO)

### RED

- [ ] Criar `test/test_csrf.jl`:

```julia
using Test
using Suindara
using HTTP

@testset "CSRF Protection" begin
    CSRF = Suindara.CSRFModule

    @testset "generate_csrf_token retorna string >= 32 chars" begin
        token = CSRF.generate_csrf_token()
        @test token isa String
        @test length(token) >= 32
    end

    @testset "is_safe_method identifica métodos seguros" begin
        @test CSRF.is_safe_method("GET") == true
        @test CSRF.is_safe_method("HEAD") == true
        @test CSRF.is_safe_method("OPTIONS") == true
        @test CSRF.is_safe_method("POST") == false
        @test CSRF.is_safe_method("PUT") == false
        @test CSRF.is_safe_method("DELETE") == false
    end

    @testset "plug_csrf permite GET sem token" begin
        plug = CSRF.make_csrf_plug()
        req = HTTP.Request("GET", "/page", [], "")
        conn = Conn(req)
        conn = assign(conn, :session_id, "test")
        conn = plug(conn)
        @test conn.halted == false
        @test haskey(conn.assigns, :csrf_token)
    end

    @testset "plug_csrf bloqueia POST sem token" begin
        plug = CSRF.make_csrf_plug()
        req = HTTP.Request("POST", "/submit", [], "")
        conn = Conn(req)
        conn = assign(conn, :session_id, "test")
        conn = plug(conn)
        @test conn.halted == true
        @test conn.status == 403
    end

    @testset "plug_csrf aceita POST com token válido no header" begin
        plug = CSRF.make_csrf_plug()

        # Primeira request GET para obter token
        req1 = HTTP.Request("GET", "/form", [], "")
        conn1 = Conn(req1)
        conn1 = assign(conn1, :session_id, "sess1")
        conn1 = plug(conn1)
        token = conn1.assigns[:csrf_token]

        # POST com o token
        req2 = HTTP.Request("POST", "/submit", ["X-CSRF-Token" => token], "")
        conn2 = Conn(req2)
        conn2 = assign(conn2, :session_id, "sess1")
        conn2 = plug(conn2)
        @test conn2.halted == false
    end

end
```

- [ ] Adicionar ao `test/runtests.jl`. Rodar → RED ✅

### GREEN

- [ ] Criar `src/CSRF.jl`:

```julia
"""
    module CSRFModule

Cross-Site Request Forgery protection plug.
Gera token por sessão, valida em requests mutantes (POST/PUT/PATCH/DELETE).
"""
module CSRFModule

using ..ConnModule
using HTTP
using Random

export make_csrf_plug, generate_csrf_token, is_safe_method

const SAFE_METHODS = Set(["GET", "HEAD", "OPTIONS"])

# Armazena tokens por session_id
const _TOKEN_STORE = Dict{String, String}()

function generate_csrf_token()::String
    return bytes2hex(rand(UInt8, 32))
end

function is_safe_method(method::String)::Bool
    return method in SAFE_METHODS
end

function get_or_create_token(session_id::String)::String
    if !haskey(_TOKEN_STORE, session_id)
        _TOKEN_STORE[session_id] = generate_csrf_token()
    end
    return _TOKEN_STORE[session_id]
end

function extract_submitted_token(conn::Conn)::String
    # Check header first, then form params
    header_token = HTTP.header(conn.request, "X-CSRF-Token", "")
    if !isempty(header_token)
        return header_token
    end
    return get(conn.params, "_csrf_token", "")
end

function make_csrf_plug()::Function
    return function(conn::Conn)::Conn
        session_id = get(conn.assigns, :session_id, "anonymous")
        token = get_or_create_token(string(session_id))
        conn = assign(conn, :csrf_token, token)

        if is_safe_method(conn.request.method)
            return conn
        end

        submitted = extract_submitted_token(conn)
        if submitted != token
            return halt!(conn, 403, "Invalid CSRF token")
        end

        return conn
    end
end

end # module
```

- [ ] Editar `src/Suindara.jl`: include, using, export.
- [ ] Rodar testes. GREEN ✅ → DONE ✅

---

## Tarefa 4.4: Documentação com Documenter.jl

**Objetivo**: Setup básico de documentação para gerar docs estáticos.

**Arquivos**:
- `docs/make.jl` (NOVO)
- `docs/src/index.md` (NOVO)
- `docs/Project.toml` (NOVO)

**NOTA**: Esta tarefa NÃO tem TDD (é documentação), mas tem passos verificáveis.

- [ ] Criar `docs/Project.toml`:

```toml
[deps]
Documenter = "e30172f5-a6a5-5a46-863b-614d45cd2de4"
Suindara = "uuid-do-suindara-do-Project.toml"
```

> **INSTRUÇÃO**: Substituir `uuid-do-suindara-do-Project.toml` pelo UUID real que está em `/home/micelio/git/Suindara.jl/Project.toml`.

- [ ] Criar `docs/src/index.md`:

```markdown
# Suindara.jl

Phoenix-inspired web framework for Julia.

## Quick Start

\```julia
using Suindara

# Define a router
@router MyRouter begin
    get("/", conn -> resp(conn, 200, "Hello!"))
end

# Start server (via HTTP.jl)
\```

## Modules

```@docs
Conn
assign
halt!
resp
run_pipeline
plug_cors
plug_request_id
plug_form_parser
make_static_plug
make_bearer_plug
cast
validate_required
validate_format
validate_length
validate_inclusion
```
```

- [ ] Criar `docs/make.jl`:

```julia
using Documenter
using Suindara

makedocs(
    sitename = "Suindara.jl",
    format = Documenter.HTML(),
    pages = [
        "Home" => "index.md",
    ]
)
```

- [ ] Verificar: `cd /home/micelio/git/Suindara.jl && julia --project=docs docs/make.jl` — deve gerar `docs/build/` sem erros.
- [ ] DONE ✅

---

## Tarefa 4.5: Benchmark Suite Automatizada

**Arquivos**: `benchmark/run_benchmarks.jl` (NOVO), `test/test_benchmark_smoke.jl` (NOVO)

### RED

- [ ] Criar `test/test_benchmark_smoke.jl`:

```julia
using Test
using Suindara

@testset "Benchmark Smoke Tests" begin

    @testset "bench_pipeline_throughput roda sem erro" begin
        result = Suindara.BenchmarkSuite.bench_pipeline_throughput(100)
        @test result isa Float64
        @test result > 0.0
    end

    @testset "bench_json_parse roda sem erro" begin
        result = Suindara.BenchmarkSuite.bench_json_parse(100)
        @test result isa Float64
        @test result > 0.0
    end

    @testset "bench_route_matching roda sem erro" begin
        result = Suindara.BenchmarkSuite.bench_route_matching(100)
        @test result isa Float64
        @test result > 0.0
    end

    @testset "format_report retorna string formatada" begin
        results = Dict("pipeline" => 1.5, "json" => 2.3)
        report = Suindara.BenchmarkSuite.format_report(results)
        @test report isa String
        @test contains(report, "pipeline")
        @test contains(report, "1.5")
    end

end
```

- [ ] Adicionar ao `test/runtests.jl`. Rodar → RED ✅

### GREEN

- [ ] Criar `src/BenchmarkSuite.jl`:

```julia
"""
    module BenchmarkSuite

Suite de benchmarks internos para medir performance das operações core.
Cada função retorna tempo médio por operação em milissegundos.
"""
module BenchmarkSuite

using ..ConnModule
using ..RouterModule
using ..WebModule
using HTTP
using JSON3

export bench_pipeline_throughput, bench_json_parse, bench_route_matching, format_report

"""
    bench_pipeline_throughput(n::Int) :: Float64

Mede ms/operação para processar n requests pelo pipeline.
"""
function bench_pipeline_throughput(n::Int)::Float64
    noop(c) = c
    plugs = [noop, noop, noop]
    req = HTTP.Request("GET", "/", [], "")

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

Formata resultados de benchmark para impressão. Função pura.
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
```

- [ ] Criar `benchmark/run_benchmarks.jl`:

```julia
#!/usr/bin/env julia
using Suindara

BS = Suindara.BenchmarkSuite
N = 10_000

results = Dict(
    "pipeline" => BS.bench_pipeline_throughput(N),
    "json_parse" => BS.bench_json_parse(N),
    "route_matching" => BS.bench_route_matching(N),
)

println(BS.format_report(results))
```

- [ ] Editar `src/Suindara.jl`: include, using.
- [ ] Rodar testes. GREEN ✅ → DONE ✅

---

## Tarefa 4.6: Publicação no Julia General Registry

**NOTA**: Esta tarefa NÃO é código — é um checklist de ações.

- [ ] Confirmar que `Project.toml` tem:
  - `name = "Suindara"`
  - `uuid` válido
  - `version = "1.0.0"`
  - `[compat]` com versões mínimas de TODAS as dependências
  - `julia = "1.10"` em `[compat]`

- [ ] Confirmar que TODOS os testes passam: `julia --project=. test/runtests.jl`

- [ ] Confirmar que a documentação gera sem erro: `julia --project=docs docs/make.jl`

- [ ] Criar tag git: `git tag v1.0.0`

- [ ] Registrar no Julia General Registry:
  - Via JuliaRegistrator bot no GitHub: abrir issue ou PR com `@JuliaRegistrator register`
  - OU usar `LocalRegistry.jl` para registros locais

- [ ] Aguardar merge da PR no General Registry (geralmente 3 dias para novos pacotes)

- [ ] DONE ✅

---

## Checklist Final da Fase 4

- [ ] Rodar `julia --project=. test/runtests.jl` — TODOS os testes passam
- [ ] Rodar `julia --project=docs docs/make.jl` — documentação gera sem erro
- [ ] Rodar `julia --project=. benchmark/run_benchmarks.jl` — benchmarks rodam
- [ ] Atualizar `Project.toml` version para `1.0.0`
- [ ] Commitar: `git add . && git commit -m "v1.0.0: Suindara.jl — Full-stack Julia web framework"`
- [ ] Tag: `git tag v1.0.0 && git push --tags`
