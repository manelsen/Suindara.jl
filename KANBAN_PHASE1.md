# KANBAN — FASE 1: Fundação Sólida (v0.3 → v0.4)

> **REGRAS PARA A IA EXECUTORA:**
>
> 1. **TDD RIGOROSO**: NUNCA escreva código de produção antes do teste. A ordem é RED → GREEN → REFACTOR. Sempre.
> 2. **FUNÇÕES PURAS E MINÚSCULAS**: Cada função faz UMA coisa só. Se a função tem mais de 15 linhas, quebre em duas.
> 3. **RODAR TESTES**: Após cada passo GREEN ou REFACTOR, rode `julia --project=. test/runtests.jl` e confirme que TODOS os testes passam.
> 4. **NOMES DE ARQUIVO**: Cada tarefa indica EXATAMENTE quais arquivos criar/editar. Siga à risca.
> 5. **NÃO PULE ETAPAS**: Cada checkbox `- [ ]` é uma micro-tarefa. Faça uma de cada vez, na ordem.

---

## Tarefa 1.1: Hot-Reload via Revise.jl

**Objetivo**: Permitir que o desenvolvedor edite código e veja mudanças sem reiniciar o servidor.

**Arquivos envolvidos**:
- `src/HotReload.jl` (NOVO)
- `src/Suindara.jl` (EDITAR — adicionar include e export)
- `test/test_hot_reload.jl` (NOVO)
- `test/runtests.jl` (EDITAR — adicionar include)

### RED: Escrever os testes PRIMEIRO

- [ ] Criar o arquivo `test/test_hot_reload.jl` com o conteúdo EXATO abaixo:

```julia
using Test
using Suindara

@testset "HotReload Module" begin

    @testset "revise_available() retorna Bool" begin
        # A função deve retornar true se Revise está carregado, false caso contrário.
        # Em ambiente de teste, Revise provavelmente NÃO está carregado.
        result = Suindara.HotReloadModule.revise_available()
        @test result isa Bool
    end

    @testset "start_watching() não explode quando Revise ausente" begin
        # Quando Revise NÃO está disponível, start_watching() deve:
        # 1. Não lançar erro
        # 2. Retornar :no_revise symbol
        result = Suindara.HotReloadModule.start_watching()
        @test result == :no_revise
    end

    @testset "watched_paths() retorna vetor vazio sem Revise" begin
        paths = Suindara.HotReloadModule.watched_paths()
        @test paths isa Vector{String}
        @test isempty(paths)
    end

end
```

- [ ] Adicionar `include("test_hot_reload.jl")` ao final de `test/runtests.jl`.
- [ ] Rodar `julia --project=. test/runtests.jl`. Confirmar que os testes FALHAM (NameError/UndefVarError — o módulo ainda não existe). Isso é o RED.

### GREEN: Implementar o mínimo para os testes passarem

- [ ] Criar o arquivo `src/HotReload.jl` com o conteúdo EXATO abaixo:

```julia
"""
    module HotReloadModule

Integração opcional com Revise.jl para recarregamento automático de código.
Se Revise.jl não estiver instalado, todas as funções são no-ops seguros.
"""
module HotReloadModule

export revise_available, start_watching, watched_paths

"""
    revise_available() :: Bool

Retorna `true` se o pacote Revise.jl está carregado no ambiente atual.
Função pura: apenas consulta o estado do módulo Main.
"""
function revise_available()::Bool
    return isdefined(Main, :Revise)
end

"""
    start_watching() :: Symbol

Inicia o tracking de arquivos com Revise.jl.
- Se Revise está disponível: chama Revise.revise() e retorna :watching.
- Se Revise NÃO está disponível: retorna :no_revise (no-op seguro).
"""
function start_watching()::Symbol
    if !revise_available()
        return :no_revise
    end
    try
        Main.Revise.revise()
        return :watching
    catch e
        @warn "HotReload: falha ao iniciar Revise" exception = e
        return :error
    end
end

"""
    watched_paths() :: Vector{String}

Retorna a lista de caminhos sendo monitorados por Revise.
Retorna vetor vazio se Revise não está disponível.
"""
function watched_paths()::Vector{String}
    if !revise_available()
        return String[]
    end
    try
        return collect(keys(Main.Revise.watched_files))
    catch
        return String[]
    end
end

end # module
```

- [ ] Editar `src/Suindara.jl` — adicionar DUAS linhas:
  - Após a linha `include("Generator.jl")`, adicionar: `include("HotReload.jl")`
  - Após a linha `using .GeneratorModule`, adicionar: `using .HotReloadModule`
  - Na linha de exports, adicionar: `export revise_available, start_watching`

- [ ] Rodar `julia --project=. test/runtests.jl`. Confirmar que TODOS os testes passam (inclusive os 3 novos). Isso é o GREEN.

### REFACTOR: Limpar sem quebrar testes

- [ ] Verificar se cada função tem docstring. Já tem — OK.
- [ ] Rodar `julia --project=. test/runtests.jl` novamente. Todos devem passar.
- [ ] DONE ✅

---

## Tarefa 1.2: Scope e Pipe-Through no Router

**Objetivo**: Permitir agrupar rotas com prefixo (`scope "/api"`) e aplicar pipelines a grupos (`pipe_through :api`).

**Arquivos envolvidos**:
- `src/Router.jl` (EDITAR — adicionar `scope`, `pipe_through`, pipeline registry)
- `test/test_scoped_router.jl` (NOVO)
- `test/runtests.jl` (EDITAR — adicionar include)

### RED: Escrever os testes PRIMEIRO

- [ ] Criar o arquivo `test/test_scoped_router.jl` com o conteúdo EXATO abaixo:

```julia
using Test
using Suindara
using HTTP

# --- Helpers: funções puras minúsculas ---
dummy_index(conn) = resp(conn, 200, "index")
dummy_show(conn) = resp(conn, 200, "show:$(conn.params["id"])")
plug_add_header(conn) = begin
    push!(conn.resp_headers, "X-Pipeline" => "applied")
    conn
end
plug_add_auth(conn) = begin
    conn = assign(conn, :authed, true)
    conn
end

@testset "Scoped Router" begin

    @testset "scope adiciona prefixo ao path" begin
        @router ScopeTestRouter begin
            scope "/api" do
                get("/users", dummy_index)
                get("/users/:id", dummy_show)
            end
        end

        # GET /api/users deve funcionar
        req1 = HTTP.Request("GET", "/api/users", [], "")
        conn1 = match_and_dispatch(ScopeTestRouter, req1)
        @test conn1.status == 200
        @test conn1.resp_body == "index"

        # GET /users (sem prefixo) NÃO deve funcionar
        req2 = HTTP.Request("GET", "/users", [], "")
        conn2 = match_and_dispatch(ScopeTestRouter, req2)
        @test conn2.status == 404
    end

    @testset "scope com parâmetro dinâmico" begin
        @router ScopeParamRouter begin
            scope "/api/v1" do
                get("/items/:id", dummy_show)
            end
        end

        req = HTTP.Request("GET", "/api/v1/items/42", [], "")
        conn = match_and_dispatch(ScopeParamRouter, req)
        @test conn.status == 200
        @test conn.resp_body == "show:42"
    end

    @testset "scope aninhado" begin
        @router NestedScopeRouter begin
            scope "/api" do
                scope "/v2" do
                    get("/health", dummy_index)
                end
            end
        end

        req = HTTP.Request("GET", "/api/v2/health", [], "")
        conn = match_and_dispatch(NestedScopeRouter, req)
        @test conn.status == 200
    end

    @testset "pipeline aplica plugs a rotas dentro do scope" begin
        @router PipelineRouter begin
            pipeline :web do
                plug(plug_add_header)
            end

            scope "/app" do
                pipe_through(:web)
                get("/home", dummy_index)
            end
        end

        req = HTTP.Request("GET", "/app/home", [], "")
        conn = match_and_dispatch(PipelineRouter, req)
        @test conn.status == 200
        @test any(h -> h == ("X-Pipeline" => "applied"), conn.resp_headers)
    end

    @testset "múltiplos pipelines compostos" begin
        @router MultiPipeRouter begin
            pipeline :auth do
                plug(plug_add_auth)
            end
            pipeline :headers do
                plug(plug_add_header)
            end

            scope "/secure" do
                pipe_through(:auth)
                pipe_through(:headers)
                get("/data", dummy_index)
            end
        end

        req = HTTP.Request("GET", "/secure/data", [], "")
        conn = match_and_dispatch(MultiPipeRouter, req)
        @test conn.status == 200
        @test conn.assigns[:authed] == true
        @test any(h -> h == ("X-Pipeline" => "applied"), conn.resp_headers)
    end

    @testset "rotas fora de scope não recebem pipeline" begin
        @router MixedRouter begin
            pipeline :special do
                plug(plug_add_header)
            end

            get("/public", dummy_index)

            scope "/private" do
                pipe_through(:special)
                get("/secret", dummy_index)
            end
        end

        # Rota pública: sem header X-Pipeline
        req1 = HTTP.Request("GET", "/public", [], "")
        conn1 = match_and_dispatch(MixedRouter, req1)
        @test conn1.status == 200
        @test !any(h -> h.first == "X-Pipeline", conn1.resp_headers)

        # Rota privada: com header X-Pipeline
        req2 = HTTP.Request("GET", "/private/secret", [], "")
        conn2 = match_and_dispatch(MixedRouter, req2)
        @test conn2.status == 200
        @test any(h -> h == ("X-Pipeline" => "applied"), conn2.resp_headers)
    end

end
```

- [ ] Adicionar `include("test_scoped_router.jl")` ao final de `test/runtests.jl`.
- [ ] Rodar testes. Confirmar que FALHAM (as macros `scope`, `pipeline`, `pipe_through`, `plug` dentro de `@router` não existem). Isso é o RED.

### GREEN: Implementar scope, pipeline, pipe_through na macro @router

A implementação requer reescrever a macro `@router` em `src/Router.jl`. A macro precisa agora:

1. Manter um registrador de pipelines: `Dict{Symbol, Vector{Expr}}` —  nome → lista de plugs
2. Entender `scope(prefix) do ... end` — concatenar o prefixo ao path de cada rota interna
3. Entender `pipeline(name) do ... end` — registrar plugs sob um nome
4. Entender `pipe_through(name)` — marcar que rotas subsequentes naquele scope usam aquele pipeline
5. Na hora de criar cada `Route`, wrappear o handler numa closure que roda `run_pipeline(conn, plugs)` ANTES de chamar o handler original

- [ ] Editar `src/Router.jl`. Abaixo está a lógica de transformação da macro. Substituir a macro `@router` existente (linhas ~140-165) pela nova implementação. **A struct `Route`, `SuindaraRouter`, `match_and_dispatch`, e `compile_route` NÃO mudam.**

A nova macro `@router` deve:

```julia
macro router(name, block)
    routes = _parse_router_block(block, "", Symbol[], Dict{Symbol, Vector}())
    quote
        $(esc(name)) = SuindaraRouter([$(routes...)])
    end
end
```

E adicionar estas funções auxiliares ACIMA da macro, dentro do módulo `RouterModule`:

```julia
# --- Funções auxiliares para parsing da DSL do @router ---

"""
    _make_pipeline_handler(handler_expr, plug_exprs)

Cria uma expressão que wrappeia o handler original num pipeline de plugs.
Se não há plugs, retorna o handler sem wrapper.
"""
function _make_pipeline_handler(handler_expr, plug_exprs::Vector)
    if isempty(plug_exprs)
        return handler_expr
    end
    plugs_vec = Expr(:vect, plug_exprs...)
    return quote
        function(conn)
            conn = run_pipeline(conn, Function[$plugs_vec...])
            if conn.halted
                return conn
            end
            return ($handler_expr)(conn)
        end
    end
end

"""
    _parse_router_block(block, prefix, active_plugs, pipelines)

Recursivamente analisa o bloco da macro @router.
Retorna um Vector de expressões que criam objetos Route.

- `prefix`: String — prefixo de path acumulado por scopes aninhados
- `active_plugs`: Vector — plugs ativos via pipe_through neste nível
- `pipelines`: Dict{Symbol, Vector} — pipelines registrados
"""
function _parse_router_block(block::Expr, prefix::String, active_plugs::Vector, pipelines::Dict)
    route_exprs = []

    if block.head != :block
        return route_exprs
    end

    for line in block.args
        if !(line isa Expr)
            continue
        end

        if line.head == :call
            method_name = string(line.args[1])

            if method_name == "pipe_through"
                # pipe_through(:name) — adicionar plugs daquela pipeline aos ativos
                pipe_name = line.args[2]
                if haskey(pipelines, pipe_name)
                    append!(active_plugs, pipelines[pipe_name])
                end

            elseif method_name in ("get", "post", "put", "patch", "delete")
                # Rota HTTP: get("/path", handler)
                method_str = uppercase(method_name)
                path_expr = line.args[2]
                handler_expr = line.args[3]

                full_path = prefix == "" ? path_expr : "$prefix$path_expr"

                wrapped_handler = _make_pipeline_handler(handler_expr, copy(active_plugs))

                push!(route_exprs, quote
                    let
                        r, names = ($(@__MODULE__)).compile_route($full_path)
                        Route($method_str, $full_path, r, names, $(esc(wrapped_handler)))
                    end
                end)
            end

        elseif line.head == :do && line.args[1] isa Expr
            call_expr = line.args[1]
            do_body = line.args[2]  # the do block body
            func_name = string(call_expr.args[1])

            if func_name == "scope"
                # scope "/prefix" do ... end
                scope_prefix = call_expr.args[2]
                new_prefix = prefix == "" ? scope_prefix : "$prefix$scope_prefix"
                child_plugs = copy(active_plugs)
                # Extract the actual block from the do body (it's wrapped in -> args)
                inner_block = do_body.args[end]
                child_routes = _parse_router_block(inner_block, new_prefix, child_plugs, pipelines)
                append!(route_exprs, child_routes)

            elseif func_name == "pipeline"
                # pipeline :name do plug(...) end
                pipe_name = call_expr.args[2]
                inner_block = do_body.args[end]
                plug_list = []
                for plug_line in inner_block.args
                    if plug_line isa Expr && plug_line.head == :call && string(plug_line.args[1]) == "plug"
                        push!(plug_list, plug_line.args[2])
                    end
                end
                pipelines[pipe_name] = plug_list
            end
        end
    end

    return route_exprs
end
```

> **NOTA PARA A IA EXECUTORA**: A lógica acima é uma REFERÊNCIA conceitual. O parsing exato de `Expr` do Julia pode exigir ajustes nos `args` indices dependendo de como Julia parseia `do...end` blocks. Use `dump(quote ... end)` para debugar a estrutura AST se os testes falharem. O critério de sucesso são os TESTES passando, não o código ser idêntico à referência.

- [ ] Rodar `julia --project=. test/runtests.jl`. Os 6 novos testsets devem TODOS passar. Os testes antigos (`test_dynamic_router.jl`, etc.) TAMBÉM devem continuar passando. Isso é o GREEN.

### REFACTOR

- [ ] Extrair `_make_pipeline_handler` e `_parse_router_block` para funções separadas se ainda não estão (já estão no design acima — confirmar).
- [ ] Confirmar que cada função tem docstring.
- [ ] Rodar testes novamente. Todos passam → DONE ✅

---

## Tarefa 1.3: Plug CORS Built-In

**Objetivo**: Fornecer um plug `plug_cors` pronto para uso, configurável, que trate preflight OPTIONS.

**Arquivos envolvidos**:
- `src/Cors.jl` (NOVO)
- `src/Suindara.jl` (EDITAR — include + using + export)
- `test/test_cors.jl` (NOVO)
- `test/runtests.jl` (EDITAR — include)

### RED

- [ ] Criar `test/test_cors.jl`:

```julia
using Test
using Suindara
using HTTP

@testset "CORS Plug" begin

    @testset "plug_cors adiciona headers padrão" begin
        req = HTTP.Request("GET", "/api/data", [], "")
        conn = Conn(req)
        conn = Suindara.CorsModule.plug_cors(conn)

        @test any(h -> h == ("Access-Control-Allow-Origin" => "*"), conn.resp_headers)
        @test any(h -> h == ("Access-Control-Allow-Methods" => "GET, POST, PUT, PATCH, DELETE, OPTIONS"), conn.resp_headers)
        @test any(h -> h == ("Access-Control-Allow-Headers" => "Content-Type, Authorization"), conn.resp_headers)
        @test conn.halted == false
    end

    @testset "plug_cors halts OPTIONS request com 204" begin
        req = HTTP.Request("OPTIONS", "/api/data", [], "")
        conn = Conn(req)
        conn = Suindara.CorsModule.plug_cors(conn)

        @test conn.status == 204
        @test conn.halted == true
        @test conn.resp_body == ""
    end

    @testset "make_cors_plug com origin customizada" begin
        custom_plug = Suindara.CorsModule.make_cors_plug(
            allow_origin="https://myapp.com",
            allow_methods="GET, POST",
            allow_headers="X-Custom"
        )

        req = HTTP.Request("GET", "/", [], "")
        conn = Conn(req)
        conn = custom_plug(conn)

        @test any(h -> h == ("Access-Control-Allow-Origin" => "https://myapp.com"), conn.resp_headers)
        @test any(h -> h == ("Access-Control-Allow-Methods" => "GET, POST"), conn.resp_headers)
        @test any(h -> h == ("Access-Control-Allow-Headers" => "X-Custom"), conn.resp_headers)
    end

    @testset "make_cors_plug com OPTIONS e origin customizada" begin
        custom_plug = Suindara.CorsModule.make_cors_plug(allow_origin="https://x.com")
        req = HTTP.Request("OPTIONS", "/", [], "")
        conn = Conn(req)
        conn = custom_plug(conn)
        @test conn.halted == true
        @test conn.status == 204
    end

end
```

- [ ] Adicionar `include("test_cors.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. Devem FALHAR (módulo CorsModule não existe). RED ✅

### GREEN

- [ ] Criar `src/Cors.jl`:

```julia
"""
    module CorsModule

Fornece plugs de CORS (Cross-Origin Resource Sharing) para o pipeline Suindara.
Inclui um plug padrão permissivo e uma factory para configuração customizada.
"""
module CorsModule

using ..ConnModule
using HTTP

export plug_cors, make_cors_plug

const DEFAULT_ORIGIN = "*"
const DEFAULT_METHODS = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
const DEFAULT_HEADERS = "Content-Type, Authorization"

"""
    add_cors_headers!(conn, origin, methods, headers) :: Conn

Função pura que adiciona os 3 headers CORS ao conn.
"""
function add_cors_headers!(conn::Conn, origin::String, methods::String, headers::String)::Conn
    push!(conn.resp_headers, "Access-Control-Allow-Origin" => origin)
    push!(conn.resp_headers, "Access-Control-Allow-Methods" => methods)
    push!(conn.resp_headers, "Access-Control-Allow-Headers" => headers)
    return conn
end

"""
    is_preflight(conn) :: Bool

Retorna true se a request é um preflight OPTIONS.
"""
function is_preflight(conn::Conn)::Bool
    return conn.request.method == "OPTIONS"
end

"""
    plug_cors(conn::Conn) :: Conn

Plug CORS com configuração padrão permissiva (origin="*").
Halts com 204 em requests OPTIONS (preflight).
"""
function plug_cors(conn::Conn)::Conn
    conn = add_cors_headers!(conn, DEFAULT_ORIGIN, DEFAULT_METHODS, DEFAULT_HEADERS)
    if is_preflight(conn)
        return halt!(conn, 204, "")
    end
    return conn
end

"""
    make_cors_plug(; allow_origin, allow_methods, allow_headers) :: Function

Factory que retorna um plug CORS customizado.
Uso: `custom_cors = make_cors_plug(allow_origin="https://myapp.com")`
"""
function make_cors_plug(;
    allow_origin::String = DEFAULT_ORIGIN,
    allow_methods::String = DEFAULT_METHODS,
    allow_headers::String = DEFAULT_HEADERS
)::Function
    return function(conn::Conn)::Conn
        conn = add_cors_headers!(conn, allow_origin, allow_methods, allow_headers)
        if is_preflight(conn)
            return halt!(conn, 204, "")
        end
        return conn
    end
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - Após `include("HotReload.jl")`, adicionar: `include("Cors.jl")`
  - Após `using .HotReloadModule`, adicionar: `using .CorsModule`
  - Aos exports, adicionar: `export plug_cors, make_cors_plug`

- [ ] Rodar testes. TODOS devem passar. GREEN ✅

### REFACTOR

- [ ] Confirmar docstrings em todas as funções.
- [ ] Rodar testes. DONE ✅

---

## Tarefa 1.4: Logging Estruturado

**Objetivo**: Plug que loga cada request com request_id, método, path, status, latência em ms.

**Arquivos envolvidos**:
- `src/Logger.jl` (NOVO)
- `src/Suindara.jl` (EDITAR)
- `test/test_logger.jl` (NOVO)
- `test/runtests.jl` (EDITAR)

### RED

- [ ] Criar `test/test_logger.jl`:

```julia
using Test
using Suindara
using HTTP

@testset "Logger Module" begin

    @testset "generate_request_id retorna UUID-like string" begin
        id = Suindara.LoggerModule.generate_request_id()
        @test id isa String
        @test length(id) >= 8
    end

    @testset "generate_request_id retorna valores únicos" begin
        id1 = Suindara.LoggerModule.generate_request_id()
        id2 = Suindara.LoggerModule.generate_request_id()
        @test id1 != id2
    end

    @testset "plug_request_id atribui ID no assigns" begin
        req = HTTP.Request("GET", "/test", [], "")
        conn = Conn(req)
        conn = Suindara.LoggerModule.plug_request_id(conn)
        @test haskey(conn.assigns, :request_id)
        @test conn.assigns[:request_id] isa String
    end

    @testset "plug_request_id preserva X-Request-ID existente" begin
        req = HTTP.Request("GET", "/test", ["X-Request-ID" => "my-custom-id"], "")
        conn = Conn(req)
        conn = Suindara.LoggerModule.plug_request_id(conn)
        @test conn.assigns[:request_id] == "my-custom-id"
    end

    @testset "plug_request_id adiciona header na resposta" begin
        req = HTTP.Request("GET", "/test", [], "")
        conn = Conn(req)
        conn = Suindara.LoggerModule.plug_request_id(conn)
        @test any(h -> h.first == "X-Request-ID", conn.resp_headers)
    end

    @testset "format_log_line retorna string formatada" begin
        line = Suindara.LoggerModule.format_log_line("abc123", "GET", "/users", 200, 12.5)
        @test contains(line, "abc123")
        @test contains(line, "GET")
        @test contains(line, "/users")
        @test contains(line, "200")
        @test contains(line, "12.5")
    end

end
```

- [ ] Adicionar `include("test_logger.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. RED (falham porque LoggerModule não existe).

### GREEN

- [ ] Criar `src/Logger.jl`:

```julia
"""
    module LoggerModule

Plugs de logging estruturado para o pipeline Suindara.
Adiciona request ID único e formata logs com método, path, status e latência.
"""
module LoggerModule

using ..ConnModule
using HTTP
using UUIDs

export plug_request_id, format_log_line, generate_request_id

"""
    generate_request_id() :: String

Gera um UUID v4 como string. Função pura (sem side-effects além de RNG).
"""
function generate_request_id()::String
    return string(uuid4())
end

"""
    extract_existing_request_id(conn) :: Union{String, Nothing}

Extrai o header X-Request-ID da request, ou retorna nothing.
"""
function extract_existing_request_id(conn::Conn)::Union{String, Nothing}
    return HTTP.header(conn.request, "X-Request-ID", nothing)
end

"""
    plug_request_id(conn::Conn) :: Conn

Plug que:
1. Lê X-Request-ID do header (se existir) ou gera um novo.
2. Armazena em conn.assigns[:request_id].
3. Adiciona X-Request-ID no header de resposta.
"""
function plug_request_id(conn::Conn)::Conn
    existing = extract_existing_request_id(conn)
    req_id = existing !== nothing ? existing : generate_request_id()

    conn = assign(conn, :request_id, req_id)
    push!(conn.resp_headers, "X-Request-ID" => req_id)
    return conn
end

"""
    format_log_line(request_id, method, path, status, latency_ms) :: String

Formata uma linha de log estruturada. Função pura: recebe dados, retorna string.
"""
function format_log_line(request_id::String, method::String, path::String, status::Int, latency_ms::Float64)::String
    return "[$(request_id)] $(method) $(path) → $(status) ($(latency_ms)ms)"
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - Adicionar `include("Logger.jl")` após o include de Cors.jl
  - Adicionar `using .LoggerModule`
  - Exportar: `export plug_request_id, format_log_line`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Tarefa 1.5: Validações Extras no Changeset

**Objetivo**: Adicionar `validate_format`, `validate_length`, `validate_inclusion` ao ChangesetModule.

**Arquivos envolvidos**:
- `src/Changeset.jl` (EDITAR)
- `test/test_changeset_validations.jl` (NOVO)
- `test/runtests.jl` (EDITAR)
- `src/Suindara.jl` (EDITAR — exports)

### RED

- [ ] Criar `test/test_changeset_validations.jl`:

```julia
using Test
using Suindara

@testset "Changeset Advanced Validations" begin

    @testset "validate_format: aceita valor que bate com regex" begin
        ch = cast(Dict("email" => "user@test.com"), [:email])
        ch = validate_format(ch, :email, r"^[^@]+@[^@]+\.[^@]+$")
        @test ch.valid == true
        @test isempty(ch.errors)
    end

    @testset "validate_format: rejeita valor que não bate" begin
        ch = cast(Dict("email" => "invalid"), [:email])
        ch = validate_format(ch, :email, r"^[^@]+@[^@]+\.[^@]+$")
        @test ch.valid == false
        @test haskey(ch.errors, :email)
        @test any(e -> contains(e, "format"), ch.errors[:email])
    end

    @testset "validate_format: ignora campo ausente" begin
        ch = cast(Dict("name" => "Ana"), [:name, :email])
        ch = validate_format(ch, :email, r".*")
        @test ch.valid == true
    end

    @testset "validate_length: aceita string dentro do range" begin
        ch = cast(Dict("name" => "Julia"), [:name])
        ch = validate_length(ch, :name, min=2, max=50)
        @test ch.valid == true
    end

    @testset "validate_length: rejeita string curta demais" begin
        ch = cast(Dict("name" => "J"), [:name])
        ch = validate_length(ch, :name, min=2, max=50)
        @test ch.valid == false
        @test haskey(ch.errors, :name)
    end

    @testset "validate_length: rejeita string longa demais" begin
        ch = cast(Dict("name" => "A"^51), [:name])
        ch = validate_length(ch, :name, min=2, max=50)
        @test ch.valid == false
    end

    @testset "validate_length: ignora campo ausente" begin
        ch = cast(Dict("x" => "y"), [:x, :name])
        ch = validate_length(ch, :name, min=1, max=10)
        @test ch.valid == true
    end

    @testset "validate_inclusion: aceita valor na lista" begin
        ch = cast(Dict("role" => "admin"), [:role])
        ch = validate_inclusion(ch, :role, ["admin", "user", "guest"])
        @test ch.valid == true
    end

    @testset "validate_inclusion: rejeita valor fora da lista" begin
        ch = cast(Dict("role" => "hacker"), [:role])
        ch = validate_inclusion(ch, :role, ["admin", "user", "guest"])
        @test ch.valid == false
        @test haskey(ch.errors, :role)
        @test any(e -> contains(e, "inclusion"), ch.errors[:role])
    end

    @testset "validate_inclusion: ignora campo ausente" begin
        ch = cast(Dict("x" => "y"), [:x, :role])
        ch = validate_inclusion(ch, :role, ["a", "b"])
        @test ch.valid == true
    end

    @testset "composição: múltiplas validações encadeadas" begin
        ch = cast(Dict("email" => "bad", "role" => "hacker"), [:email, :role])
        ch = validate_format(ch, :email, r"^[^@]+@[^@]+\.[^@]+$")
        ch = validate_inclusion(ch, :role, ["admin", "user"])
        @test ch.valid == false
        @test length(ch.errors) == 2
    end

end
```

- [ ] Adicionar `include("test_changeset_validations.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM (funções não existem). RED ✅

### GREEN

- [ ] Editar `src/Changeset.jl` — adicionar 3 funções ANTES de `end # module`:

```julia
"""
    validate_format(ch::Changeset, field::Symbol, pattern::Regex) :: Changeset

Valida que o valor do campo corresponde ao padrão regex.
Ignora o campo se ele não está presente nos changes (validação condicional).
"""
function validate_format(ch::Changeset, field::Symbol, pattern::Regex)::Changeset
    if !haskey(ch.changes, field)
        return ch
    end
    value = string(ch.changes[field])
    if !occursin(pattern, value)
        push_error!(ch, field, "has invalid format")
    end
    return ch
end

"""
    validate_length(ch::Changeset, field::Symbol; min::Int=0, max::Int=typemax(Int)) :: Changeset

Valida que o comprimento da string está entre min e max (inclusive).
Ignora o campo se ausente.
"""
function validate_length(ch::Changeset, field::Symbol; min::Int=0, max::Int=typemax(Int))::Changeset
    if !haskey(ch.changes, field)
        return ch
    end
    len = length(string(ch.changes[field]))
    if len < min
        push_error!(ch, field, "should be at least $min character(s)")
    elseif len > max
        push_error!(ch, field, "should be at most $max character(s)")
    end
    return ch
end

"""
    validate_inclusion(ch::Changeset, field::Symbol, allowed::Vector) :: Changeset

Valida que o valor do campo está na lista de valores permitidos.
Ignora o campo se ausente.
"""
function validate_inclusion(ch::Changeset, field::Symbol, allowed::Vector)::Changeset
    if !haskey(ch.changes, field)
        return ch
    end
    if !(ch.changes[field] in allowed)
        push_error!(ch, field, "is not included in the list of allowed values (inclusion)")
    end
    return ch
end
```

- [ ] Editar `src/Changeset.jl` — na linha `export`, adicionar as 3 novas funções:
  - `export Changeset, cast, validate_required, validate_format, validate_length, validate_inclusion`

- [ ] Editar `src/Suindara.jl` — na linha de exports que contém Changeset, adicionar:
  - `export validate_format, validate_length, validate_inclusion`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Tarefa 1.6: Static File Serving

**Objetivo**: Plug que serve arquivos estáticos de um diretório (CSS, JS, imagens).

**Arquivos envolvidos**:
- `src/StaticFile.jl` (NOVO)
- `src/Suindara.jl` (EDITAR)
- `test/test_static_file.jl` (NOVO)
- `test/runtests.jl` (EDITAR)

### RED

- [ ] Criar `test/test_static_file.jl`:

```julia
using Test
using Suindara
using HTTP

@testset "Static File Serving" begin

    # Setup: criar diretório temporário com arquivo de teste
    test_dir = mktempdir()
    write(joinpath(test_dir, "style.css"), "body { color: red; }")
    write(joinpath(test_dir, "app.js"), "console.log('hi');")
    mkdir(joinpath(test_dir, "img"))
    write(joinpath(test_dir, "img", "logo.png"), "FAKE_PNG_DATA")

    @testset "guess_mime_type retorna tipo correto" begin
        @test Suindara.StaticFileModule.guess_mime_type("style.css") == "text/css"
        @test Suindara.StaticFileModule.guess_mime_type("app.js") == "application/javascript"
        @test Suindara.StaticFileModule.guess_mime_type("logo.png") == "image/png"
        @test Suindara.StaticFileModule.guess_mime_type("photo.jpg") == "image/jpeg"
        @test Suindara.StaticFileModule.guess_mime_type("data.json") == "application/json"
        @test Suindara.StaticFileModule.guess_mime_type("unknown.xyz") == "application/octet-stream"
    end

    @testset "sanitize_path rejeita path traversal" begin
        @test Suindara.StaticFileModule.sanitize_path("../etc/passwd") === nothing
        @test Suindara.StaticFileModule.sanitize_path("..%2f..%2fetc") === nothing
        @test Suindara.StaticFileModule.sanitize_path("style.css") == "style.css"
        @test Suindara.StaticFileModule.sanitize_path("img/logo.png") == "img/logo.png"
    end

    @testset "make_static_plug serve arquivo existente" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/static/style.css", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.status == 200
        @test conn.resp_body == "body { color: red; }"
        @test any(h -> h == ("Content-Type" => "text/css"), conn.resp_headers)
        @test conn.halted == true  # static plug halts the pipeline
    end

    @testset "make_static_plug serve arquivo em subdiretório" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/static/img/logo.png", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.status == 200
        @test conn.resp_body == "FAKE_PNG_DATA"
    end

    @testset "make_static_plug ignora rotas que não começam com prefix" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/api/users", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.halted == false  # Não halt — deixa passar para o router
        @test conn.status == 200    # Status default, não modificado
    end

    @testset "make_static_plug retorna 404 para arquivo inexistente" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/static/nope.txt", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.status == 404
        @test conn.halted == true
    end

    @testset "make_static_plug bloqueia path traversal" begin
        plug = Suindara.StaticFileModule.make_static_plug(test_dir, "/static")

        req = HTTP.Request("GET", "/static/../../../etc/passwd", [], "")
        conn = Conn(req)
        conn = plug(conn)

        @test conn.status == 400
        @test conn.halted == true
    end

    # Cleanup
    rm(test_dir, recursive=true)

end
```

- [ ] Adicionar `include("test_static_file.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM. RED ✅

### GREEN

- [ ] Criar `src/StaticFile.jl`:

```julia
"""
    module StaticFileModule

Plug para servir arquivos estáticos de um diretório local.
Inclui proteção contra path traversal e detecção de MIME type.
"""
module StaticFileModule

using ..ConnModule
using HTTP

export make_static_plug, guess_mime_type, sanitize_path

const MIME_TYPES = Dict(
    ".html" => "text/html",
    ".css"  => "text/css",
    ".js"   => "application/javascript",
    ".json" => "application/json",
    ".png"  => "image/png",
    ".jpg"  => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif"  => "image/gif",
    ".svg"  => "image/svg+xml",
    ".ico"  => "image/x-icon",
    ".woff" => "font/woff",
    ".woff2"=> "font/woff2",
    ".txt"  => "text/plain",
)

"""
    guess_mime_type(filename::String) :: String

Retorna o MIME type baseado na extensão do arquivo.
Retorna "application/octet-stream" para extensões desconhecidas.
"""
function guess_mime_type(filename::String)::String
    for (ext, mime) in MIME_TYPES
        if endswith(filename, ext)
            return mime
        end
    end
    return "application/octet-stream"
end

"""
    sanitize_path(relative_path::String) :: Union{String, Nothing}

Valida que o path relativo não contém path traversal (.. ou %2f).
Retorna nothing se inseguro, ou o path limpo se seguro.
"""
function sanitize_path(relative_path::String)::Union{String, Nothing}
    decoded = HTTP.URIs.unescapeuri(relative_path)
    if contains(decoded, "..")
        return nothing
    end
    return decoded
end

"""
    make_static_plug(directory::String, url_prefix::String) :: Function

Factory que retorna um plug para servir arquivos estáticos.

- `directory`: caminho absoluto do diretório com os arquivos.
- `url_prefix`: prefixo da URL (ex: "/static").

O plug HALT a pipeline se servir um arquivo ou detectar erro.
Se a URL não começa com o prefixo, o plug NÃO faz nada (passa adiante).
"""
function make_static_plug(directory::String, url_prefix::String)::Function
    return function(conn::Conn)::Conn
        path = conn.request.target

        # Ignorar rotas que não são para arquivos estáticos
        if !startswith(path, url_prefix)
            return conn
        end

        # Extrair path relativo
        relative = path[length(url_prefix)+1:end]
        if startswith(relative, "/")
            relative = relative[2:end]
        end

        # Segurança: rejeitar path traversal
        clean_path = sanitize_path(relative)
        if clean_path === nothing
            return halt!(conn, 400, "Bad Request: invalid path")
        end

        # Construir caminho completo do arquivo
        full_path = joinpath(directory, clean_path)

        # Verificar se o arquivo existe
        if !isfile(full_path)
            return halt!(conn, 404, "File not found")
        end

        # Ler e servir o arquivo
        content = read(full_path, String)
        mime = guess_mime_type(clean_path)
        conn = resp(conn, 200, content, content_type=mime)
        conn.halted = true  # Static file served — halt pipeline
        return conn
    end
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - `include("StaticFile.jl")` após Logger.jl
  - `using .StaticFileModule`
  - `export make_static_plug`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Tarefa 1.7: Multipart/Form-Data Parsing

**Objetivo**: Plug que parseia requests `multipart/form-data` e `application/x-www-form-urlencoded` para `conn.params`.

**Arquivos envolvidos**:
- `src/FormParser.jl` (NOVO)
- `src/Suindara.jl` (EDITAR)
- `test/test_form_parser.jl` (NOVO)
- `test/runtests.jl` (EDITAR)

### RED

- [ ] Criar `test/test_form_parser.jl`:

```julia
using Test
using Suindara
using HTTP

@testset "Form Parser Module" begin

    @testset "parse_urlencoded: chave=valor simples" begin
        result = Suindara.FormParserModule.parse_urlencoded("name=Julia&version=1.10")
        @test result["name"] == "Julia"
        @test result["version"] == "1.10"
    end

    @testset "parse_urlencoded: decodifica %20 e +" begin
        result = Suindara.FormParserModule.parse_urlencoded("msg=hello+world&path=%2Ffoo")
        @test result["msg"] == "hello world"
        @test result["path"] == "/foo"
    end

    @testset "parse_urlencoded: string vazia retorna Dict vazio" begin
        result = Suindara.FormParserModule.parse_urlencoded("")
        @test isempty(result)
    end

    @testset "plug_form_parser: parseia application/x-www-form-urlencoded" begin
        body = "username=ana&age=30"
        req = HTTP.Request("POST", "/", ["Content-Type" => "application/x-www-form-urlencoded"], body)
        conn = Conn(req)
        conn = Suindara.FormParserModule.plug_form_parser(conn)
        @test conn.params["username"] == "ana"
        @test conn.params["age"] == "30"
    end

    @testset "plug_form_parser: ignora Content-Type diferente" begin
        req = HTTP.Request("POST", "/", ["Content-Type" => "text/plain"], "data=123")
        conn = Conn(req)
        conn = Suindara.FormParserModule.plug_form_parser(conn)
        @test !haskey(conn.params, "data")
    end

    @testset "plug_form_parser: não explode com body vazio" begin
        req = HTTP.Request("POST", "/", ["Content-Type" => "application/x-www-form-urlencoded"], "")
        conn = Conn(req)
        conn = Suindara.FormParserModule.plug_form_parser(conn)
        @test conn.halted == false
    end

end
```

- [ ] Adicionar `include("test_form_parser.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM. RED ✅

### GREEN

- [ ] Criar `src/FormParser.jl`:

```julia
"""
    module FormParserModule

Parseia bodies de requests com Content-Type:
- application/x-www-form-urlencoded
Merge resultado em conn.params.
"""
module FormParserModule

using ..ConnModule
using HTTP

export plug_form_parser, parse_urlencoded

"""
    decode_plus(s::String) :: String

Substitui '+' por espaço (convenção de form encoding).
"""
function decode_plus(s::String)::String
    return replace(s, '+' => ' ')
end

"""
    parse_urlencoded(body::String) :: Dict{String, Any}

Parseia uma string URL-encoded (chave=valor&chave2=valor2) para Dict.
Decodifica %XX e substitui + por espaço.
"""
function parse_urlencoded(body::String)::Dict{String, Any}
    result = Dict{String, Any}()
    if isempty(body)
        return result
    end
    for pair in split(body, '&')
        parts = split(pair, '=', limit=2)
        if length(parts) == 2
            key = HTTP.URIs.unescapeuri(decode_plus(parts[1]))
            value = HTTP.URIs.unescapeuri(decode_plus(parts[2]))
            result[key] = value
        elseif length(parts) == 1 && !isempty(parts[1])
            key = HTTP.URIs.unescapeuri(decode_plus(parts[1]))
            result[key] = ""
        end
    end
    return result
end

"""
    is_form_urlencoded(conn::Conn) :: Bool

Verifica se o Content-Type é application/x-www-form-urlencoded.
"""
function is_form_urlencoded(conn::Conn)::Bool
    ct = HTTP.header(conn.request, "Content-Type", "")
    return startswith(ct, "application/x-www-form-urlencoded")
end

"""
    plug_form_parser(conn::Conn) :: Conn

Plug que parseia form-urlencoded body e merge em conn.params.
Ignora se Content-Type não é form-urlencoded.
"""
function plug_form_parser(conn::Conn)::Conn
    if !is_form_urlencoded(conn)
        return conn
    end

    body_str = String(copy(conn.request.body))
    if isempty(body_str)
        return conn
    end

    parsed = parse_urlencoded(body_str)
    merge!(conn.params, parsed)
    return conn
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - `include("FormParser.jl")` após StaticFile.jl
  - `using .FormParserModule`
  - `export plug_form_parser`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Checklist Final da Fase 1

Após completar TODAS as 7 tarefas acima:

- [ ] Rodar `julia --project=. test/runtests.jl` — TODOS os testes passam
- [ ] Atualizar `Project.toml` version para `0.3.0`
- [ ] Atualizar `KANBAN.md` original marcando Fase 1 como completa
- [ ] Commitar: `git add . && git commit -m "v0.3.0: Phase 1 — Foundation (CORS, Logger, Validations, Static Files, Form Parser, Scoped Router, HotReload)"`
