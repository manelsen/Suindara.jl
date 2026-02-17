# KANBAN — FASE 2: Maturidade de Dados (v0.5 → v0.6)

> **REGRAS PARA A IA EXECUTORA:**
>
> 1. **TDD RIGOROSO**: NUNCA escreva código de produção antes do teste. Ordem: RED → GREEN → REFACTOR.
> 2. **FUNÇÕES PURAS E MINÚSCULAS**: Cada função faz UMA coisa só. Se tem mais de 15 linhas, quebre em duas.
> 3. **RODAR TESTES**: Após cada GREEN ou REFACTOR, rode `julia --project=. test/runtests.jl` e confirme que TODOS os testes passam.
> 4. **PRÉ-REQUISITO**: A Fase 1 (KANBAN_PHASE1.md) deve estar 100% completa antes de iniciar esta fase.
> 5. **NÃO PULE ETAPAS**: Cada checkbox `- [ ]` é uma micro-tarefa. Faça uma de cada vez, na ordem.

---

## Tarefa 2.1: Adapter Pattern no Repo (SQLite + PostgreSQL)

**Objetivo**: Refatorar o Repo para usar um padrão Adapter, permitindo trocar SQLite por PostgreSQL (via LibPQ.jl) sem mudar a API pública.

**Contexto para a IA executora**: Atualmente, `src/Repo.jl` usa diretamente `SQLite.jl`. Vamos criar uma camada de abstração com uma interface `AbstractAdapter` e dois backends: `SQLiteAdapter` e `PostgresAdapter`.

**Arquivos envolvidos**:
- `src/RepoAdapter.jl` (NOVO — interface abstrata)
- `src/adapters/SQLiteAdapter.jl` (NOVO — implementação SQLite extraída do Repo.jl atual)
- `src/adapters/PostgresAdapter.jl` (NOVO — stub para PostgreSQL)
- `src/Repo.jl` (REESCREVER — delegar ao adapter ativo)
- `src/Suindara.jl` (EDITAR — includes)
- `test/test_repo_adapter.jl` (NOVO)
- `test/runtests.jl` (EDITAR)
- `Project.toml` (EDITAR — adicionar LibPQ como dependência opcional)

### RED: Escrever os testes PRIMEIRO

- [ ] Criar `test/test_repo_adapter.jl`:

```julia
using Test
using Suindara

@testset "Repo Adapter Pattern" begin

    @testset "SQLiteAdapter implementa a interface" begin
        adapter = Suindara.Repo.SQLiteBackend.SQLiteAdapter(":memory:")
        @test adapter isa Suindara.Repo.AbstractAdapter
    end

    @testset "adapter_name retorna :sqlite para SQLiteAdapter" begin
        adapter = Suindara.Repo.SQLiteBackend.SQLiteAdapter(":memory:")
        @test Suindara.Repo.adapter_name(adapter) == :sqlite
    end

    @testset "connect via adapter sem explodir" begin
        adapter = Suindara.Repo.SQLiteBackend.SQLiteAdapter(":memory:")
        Suindara.Repo.adapter_connect!(adapter)
        @test true  # Se chegou aqui, não explodiu
    end

    @testset "execute e query via adapter" begin
        adapter = Suindara.Repo.SQLiteBackend.SQLiteAdapter(":memory:")
        Suindara.Repo.adapter_connect!(adapter)

        Suindara.Repo.adapter_execute!(adapter, "CREATE TABLE test_items (id INTEGER PRIMARY KEY, name TEXT)")
        Suindara.Repo.adapter_execute!(adapter, "INSERT INTO test_items (name) VALUES (?)", ["Item1"])

        rows = Suindara.Repo.adapter_query(adapter, "SELECT * FROM test_items")
        @test length(rows) == 1
        @test rows[1].name == "Item1"
    end

    @testset "API pública do Repo continua funcionando (retrocompatibilidade)" begin
        # O Repo.connect / Repo.query / Repo.execute devem continuar funcionando
        # exatamente como antes, usando SQLite por default.
        Suindara.Repo.connect(":memory:")

        Suindara.Repo.execute("CREATE TABLE compat_test (id INTEGER PRIMARY KEY, val TEXT)")
        Suindara.Repo.execute("INSERT INTO compat_test (val) VALUES (?)", ["hello"])

        rows = Suindara.Repo.query("SELECT * FROM compat_test")
        @test length(rows) == 1
        @test rows[1].val == "hello"
    end

    @testset "set_adapter! troca o adapter ativo" begin
        adapter = Suindara.Repo.SQLiteBackend.SQLiteAdapter(":memory:")
        Suindara.Repo.set_adapter!(adapter)
        @test Suindara.Repo.current_adapter_name() == :sqlite
    end

end
```

- [ ] Adicionar `include("test_repo_adapter.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM (nada do adapter existe). RED ✅

### GREEN: Implementar o adapter pattern

**Passo 2.1.1** — Criar `src/RepoAdapter.jl` (a interface abstrata):

- [ ] Criar o arquivo `src/RepoAdapter.jl`:

```julia
"""
    Interface abstrata para adapters de banco de dados.

Qualquer adapter (SQLite, PostgreSQL, etc.) deve ser subtipo de AbstractAdapter
e implementar as funções abaixo.
"""

"""
    abstract type AbstractAdapter

Supertipo para todos os adapters de banco de dados do Suindara.
"""
abstract type AbstractAdapter end

"""
    adapter_name(a::AbstractAdapter) :: Symbol

Retorna o nome do adapter (:sqlite, :postgres, etc).
DEVE ser implementado por cada adapter concreto.
"""
function adapter_name(::AbstractAdapter)::Symbol
    error("adapter_name not implemented")
end

"""
    adapter_connect!(a::AbstractAdapter)

Inicializa a conexão (ou pool) do adapter.
DEVE ser implementado por cada adapter concreto.
"""
function adapter_connect!(::AbstractAdapter)
    error("adapter_connect! not implemented")
end

"""
    adapter_execute!(a::AbstractAdapter, sql::String, params=())

Executa um SQL statement (INSERT, UPDATE, DELETE, CREATE, etc.).
DEVE ser implementado por cada adapter concreto.
"""
function adapter_execute!(::AbstractAdapter, sql::String, params=())
    error("adapter_execute! not implemented")
end

"""
    adapter_query(a::AbstractAdapter, sql::String, params=()) :: Vector{NamedTuple}

Executa um SQL query e retorna vetor de NamedTuples.
DEVE ser implementado por cada adapter concreto.
"""
function adapter_query(::AbstractAdapter, sql::String, params=())::Vector
    error("adapter_query not implemented")
end

"""
    adapter_transaction(a::AbstractAdapter, f::Function)

Executa a função f dentro de uma transação do banco.
DEVE ser implementado por cada adapter concreto.
"""
function adapter_transaction(::AbstractAdapter, f::Function)
    error("adapter_transaction not implemented")
end
```

**Passo 2.1.2** — Criar diretório `src/adapters/` e o `SQLiteAdapter.jl`:

- [ ] Criar o diretório `src/adapters/`
- [ ] Criar o arquivo `src/adapters/SQLiteAdapter.jl`:

```julia
"""
    module SQLiteBackend

Implementação do adapter de banco de dados para SQLite.
Extrai a lógica que estava anteriormente em Repo.jl.
"""
module SQLiteBackend

using SQLite
using DBInterface

# Import the abstract interface (will be available from parent module)
import ..AbstractAdapter, ..adapter_name, ..adapter_connect!, ..adapter_execute!, ..adapter_query, ..adapter_transaction

export SQLiteAdapter

"""
    mutable struct SQLiteAdapter <: AbstractAdapter

Adapter concreto para SQLite.
Gerencia um pool de conexões via Channel, como o Repo original fazia.
"""
mutable struct SQLiteAdapter <: AbstractAdapter
    db_path::String
    pool::Channel{SQLite.DB}
    connected::Bool

    function SQLiteAdapter(path::String)
        new(path, Channel{SQLite.DB}(32), false)
    end
end

# --- Funções auxiliares internas ---

function _exec_and_finalize!(db::SQLite.DB, sql::String, params=())
    stmt = SQLite.Stmt(db, sql; register=false)
    try
        DBInterface.execute(stmt, params)
    finally
        Base.finalize(stmt)
    end
end

function _get_conn(adapter::SQLiteAdapter, timeout_ms::Int=5000)
    if !adapter.connected
        error("SQLiteAdapter not connected. Call adapter_connect! first.")
    end
    start_time = time()
    while !isready(adapter.pool)
        if (time() - start_time) * 1000 > timeout_ms
            error("Connection pool timeout after $(timeout_ms)ms")
        end
        yield()
    end
    return take!(adapter.pool)
end

function _release_conn(adapter::SQLiteAdapter, db::SQLite.DB)
    put!(adapter.pool, db)
end

# --- Implementação da interface ---

function adapter_name(::SQLiteAdapter)::Symbol
    return :sqlite
end

function adapter_connect!(adapter::SQLiteAdapter)
    # Limpar pool se já existir
    while isready(adapter.pool)
        take!(adapter.pool)
    end

    pool_size = adapter.db_path == ":memory:" ? 1 : min(4, Sys.CPU_THREADS)

    for _ in 1:pool_size
        db = SQLite.DB(adapter.db_path)
        try
            _exec_and_finalize!(db, "PRAGMA journal_mode=WAL;")
            _exec_and_finalize!(db, "PRAGMA synchronous=NORMAL;")
            _exec_and_finalize!(db, "PRAGMA busy_timeout=5000;")
        catch e
            @warn "Failed to set PRAGMA: $e"
        end
        put!(adapter.pool, db)
    end

    adapter.connected = true
end

function adapter_execute!(adapter::SQLiteAdapter, sql::String, params=())
    db = _get_conn(adapter)
    try
        _exec_and_finalize!(db, sql, params)
    finally
        _release_conn(adapter, db)
    end
end

function adapter_query(adapter::SQLiteAdapter, sql::String, params=())::Vector
    db = _get_conn(adapter)
    try
        stmt = SQLite.Stmt(db, sql; register=false)
        try
            result = DBInterface.execute(stmt, params)
            return [NamedTuple(Symbol(k) => getproperty(row, Symbol(k)) for k in propertynames(row)) for row in result]
        finally
            Base.finalize(stmt)
        end
    finally
        _release_conn(adapter, db)
    end
end

function adapter_transaction(adapter::SQLiteAdapter, f::Function)
    db = _get_conn(adapter)
    try
        SQLite.transaction(db) do
            f()
        end
    finally
        _release_conn(adapter, db)
    end
end

end # module SQLiteBackend
```

**Passo 2.1.3** — Criar stub `src/adapters/PostgresAdapter.jl`:

- [ ] Criar `src/adapters/PostgresAdapter.jl`:

```julia
"""
    module PostgresBackend

Stub para o adapter de PostgreSQL. Será implementado completamente quando
LibPQ.jl for adicionado como dependência.

Por ora, define o tipo e lança erros informativos em cada operação.
"""
module PostgresBackend

import ..AbstractAdapter, ..adapter_name, ..adapter_connect!, ..adapter_execute!, ..adapter_query, ..adapter_transaction

export PostgresAdapter

mutable struct PostgresAdapter <: AbstractAdapter
    connection_string::String

    function PostgresAdapter(conn_str::String)
        new(conn_str)
    end
end

function adapter_name(::PostgresAdapter)::Symbol
    return :postgres
end

function adapter_connect!(::PostgresAdapter)
    error("PostgresAdapter não implementado ainda. Adicione LibPQ.jl ao Project.toml e implemente este módulo.")
end

function adapter_execute!(::PostgresAdapter, sql::String, params=())
    error("PostgresAdapter não implementado ainda.")
end

function adapter_query(::PostgresAdapter, sql::String, params=())::Vector
    error("PostgresAdapter não implementado ainda.")
end

function adapter_transaction(::PostgresAdapter, f::Function)
    error("PostgresAdapter não implementado ainda.")
end

end # module PostgresBackend
```

**Passo 2.1.4** — Reescrever `src/Repo.jl` para delegar ao adapter:

- [ ] Reescrever `src/Repo.jl`. O módulo `Repo` agora:
  1. Inclui `RepoAdapter.jl` (interface)
  2. Inclui os adapters
  3. Mantém uma referência global ao adapter ativo
  4. Delega `connect`, `query`, `execute`, `transaction` ao adapter ativo
  5. Mantém as funções CRUD (`insert`, `update`, `delete`, `get_one`) INALTERADAS

```julia
module Repo

using SQLite
using DBInterface
using ..ChangesetModule

export connect, query, execute, insert, update, delete, get_one, transaction
export set_adapter!, current_adapter_name

# --- Interface abstrata ---
include("RepoAdapter.jl")

# --- Adapters concretos ---
include("adapters/SQLiteAdapter.jl")
include("adapters/PostgresAdapter.jl")

using .SQLiteBackend
using .PostgresBackend

# --- Adapter ativo (global mutável) ---
const _ACTIVE_ADAPTER = Ref{Union{AbstractAdapter, Nothing}}(nothing)

"""
    set_adapter!(adapter::AbstractAdapter)
Define o adapter ativo para todas as operações do Repo.
"""
function set_adapter!(adapter::AbstractAdapter)
    _ACTIVE_ADAPTER[] = adapter
end

"""
    current_adapter_name() :: Symbol
Retorna o nome do adapter ativo.
"""
function current_adapter_name()::Symbol
    a = _ACTIVE_ADAPTER[]
    if a === nothing
        error("No adapter set. Call Repo.connect() or Repo.set_adapter!() first.")
    end
    return adapter_name(a)
end

function _get_adapter()::AbstractAdapter
    a = _ACTIVE_ADAPTER[]
    if a === nothing
        error("Database not connected. Call Repo.connect(path) first.")
    end
    return a
end

# --- API pública (retrocompatível) ---

"""
    connect(path::String)
Conecta ao banco usando SQLiteAdapter (comportamento padrão, retrocompatível).
"""
function connect(path::String)
    adapter = SQLiteBackend.SQLiteAdapter(path)
    adapter_connect!(adapter)
    set_adapter!(adapter)
end

"""
    query(sql::String, params=())
Executa SQL query e retorna vetor de NamedTuples.
"""
function query(sql::String, params=())
    return adapter_query(_get_adapter(), sql, params)
end

"""
    execute(sql::String, params=())
Executa SQL statement.
"""
function execute(sql::String, params=())
    adapter_execute!(_get_adapter(), sql, params)
end

"""
    transaction(f::Function)
Executa função dentro de uma transação.
"""
function transaction(f::Function)
    adapter_transaction(_get_adapter(), f)
end

# --- CRUD Operations (inalteradas) ---

function validate_name(name::String, type::String="field")
    if !occursin(r"^[a-zA-Z0-9_]+$", name)
        error("Invalid $type name: $name")
    end
end

function insert(ch::ChangesetModule.Changeset, table::String)
    if !ch.valid
        error("Cannot insert invalid changeset")
    end

    validate_name(table, "table")

    fields = keys(ch.changes) |> collect
    values_list = values(ch.changes) |> collect

    for field in fields
        validate_name(string(field))
    end

    field_names = join(fields, ", ")
    placeholders = join(["?" for _ in fields], ", ")

    sql = "INSERT INTO $table ($field_names) VALUES ($placeholders)"

    execute(sql, values_list)
    return ch
end

function update(ch::ChangesetModule.Changeset, table::String, id::Any; pk::String="id")
    if !ch.valid
        error("Cannot update invalid changeset")
    end

    validate_name(table, "table")
    validate_name(pk, "primary key")

    fields = keys(ch.changes) |> collect
    values_list = Any[values(ch.changes)...]
    push!(values_list, id)

    if isempty(fields)
        return ch
    end

    for field in fields
        validate_name(string(field))
    end

    set_clause = join(["$f = ?" for f in fields], ", ")

    sql = "UPDATE $table SET $set_clause WHERE $pk = ?"
    execute(sql, values_list)
    return ch
end

function delete(table::String, id::Any; pk::String="id")
    validate_name(table, "table")
    validate_name(pk, "primary key")

    sql = "DELETE FROM $table WHERE $pk = ?"
    execute(sql, [id])
end

function get_one(table::String, id::Any; pk::String="id")
    validate_name(table, "table")
    validate_name(pk, "primary key")

    sql = "SELECT * FROM $table WHERE $pk = ? LIMIT 1"
    results = query(sql, [id])

    if isempty(results)
        return nothing
    end
    return results[1]
end

end # module Repo
```

- [ ] Editar `src/Suindara.jl`:
  - Mover o `include("Repo.jl")` PARA DEPOIS do `include("Changeset.jl")` (se já não está — checar)
  - NÃO adicionar include de RepoAdapter.jl separadamente — ele é incluído DENTRO de Repo.jl

- [ ] Rodar `julia --project=. test/runtests.jl`. TODOS os testes devem passar — os 6 novos do adapter E todos os existentes (test_repo.jl, test_repo_crud.jl, test_repo_concurrency.jl, etc.). GREEN ✅

### REFACTOR

- [ ] Confirmar que cada função tem docstring.
- [ ] Rodar testes novamente → DONE ✅

---

## Tarefa 2.2: Query Builder Composável

**Objetivo**: API funcional para construir queries sem SQL cru, usando o pipe operator `|>`.

**Arquivos envolvidos**:
- `src/QueryBuilder.jl` (NOVO)
- `src/Suindara.jl` (EDITAR)
- `test/test_query_builder.jl` (NOVO)
- `test/runtests.jl` (EDITAR)

### RED

- [ ] Criar `test/test_query_builder.jl`:

```julia
using Test
using Suindara

@testset "Query Builder" begin

    @testset "from retorna Query base" begin
        q = Suindara.QueryBuilderModule.from("users")
        @test q isa Suindara.QueryBuilderModule.Query
        @test q.table == "users"
    end

    @testset "where adiciona condição" begin
        q = Suindara.QueryBuilderModule.from("users")
        q = Suindara.QueryBuilderModule.where(q, "active = ?", [1])
        @test length(q.conditions) == 1
        @test q.params == [1]
    end

    @testset "where encadeado com |>" begin
        q = Suindara.QueryBuilderModule.from("users") |>
            q -> Suindara.QueryBuilderModule.where(q, "active = ?", [1]) |>
            q -> Suindara.QueryBuilderModule.where(q, "role = ?", ["admin"])
        @test length(q.conditions) == 2
        @test q.params == [1, "admin"]
    end

    @testset "select define colunas" begin
        q = Suindara.QueryBuilderModule.from("users")
        q = Suindara.QueryBuilderModule.select(q, ["name", "email"])
        @test q.columns == ["name", "email"]
    end

    @testset "limit e offset" begin
        q = Suindara.QueryBuilderModule.from("users")
        q = Suindara.QueryBuilderModule.limit(q, 10)
        q = Suindara.QueryBuilderModule.offset(q, 20)
        @test q.limit_val == 10
        @test q.offset_val == 20
    end

    @testset "order_by" begin
        q = Suindara.QueryBuilderModule.from("users")
        q = Suindara.QueryBuilderModule.order_by(q, "name ASC")
        @test q.order == "name ASC"
    end

    @testset "to_sql gera SQL correto para SELECT simples" begin
        q = Suindara.QueryBuilderModule.from("users")
        sql, params = Suindara.QueryBuilderModule.to_sql(q)
        @test sql == "SELECT * FROM users"
        @test isempty(params)
    end

    @testset "to_sql gera SQL com WHERE" begin
        q = Suindara.QueryBuilderModule.from("users") |>
            q -> Suindara.QueryBuilderModule.where(q, "active = ?", [1])
        sql, params = Suindara.QueryBuilderModule.to_sql(q)
        @test sql == "SELECT * FROM users WHERE active = ?"
        @test params == [1]
    end

    @testset "to_sql gera SQL completo" begin
        q = Suindara.QueryBuilderModule.from("users") |>
            q -> Suindara.QueryBuilderModule.select(q, ["id", "name"]) |>
            q -> Suindara.QueryBuilderModule.where(q, "active = ?", [1]) |>
            q -> Suindara.QueryBuilderModule.where(q, "role = ?", ["admin"]) |>
            q -> Suindara.QueryBuilderModule.order_by(q, "name ASC") |>
            q -> Suindara.QueryBuilderModule.limit(q, 10) |>
            q -> Suindara.QueryBuilderModule.offset(q, 5)
        sql, params = Suindara.QueryBuilderModule.to_sql(q)
        @test sql == "SELECT id, name FROM users WHERE active = ? AND role = ? ORDER BY name ASC LIMIT 10 OFFSET 5"
        @test params == [1, "admin"]
    end

    @testset "all executa query no banco e retorna resultados" begin
        # Setup: conectar e criar tabela
        Suindara.Repo.connect(":memory:")
        Suindara.Repo.execute("CREATE TABLE qb_test (id INTEGER PRIMARY KEY, name TEXT, active INTEGER)")
        Suindara.Repo.execute("INSERT INTO qb_test (name, active) VALUES (?, ?)", ["Alice", 1])
        Suindara.Repo.execute("INSERT INTO qb_test (name, active) VALUES (?, ?)", ["Bob", 0])

        results = Suindara.QueryBuilderModule.from("qb_test") |>
            q -> Suindara.QueryBuilderModule.where(q, "active = ?", [1]) |>
            Suindara.QueryBuilderModule.all

        @test length(results) == 1
        @test results[1].name == "Alice"
    end

end
```

- [ ] Adicionar `include("test_query_builder.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM. RED ✅

### GREEN

- [ ] Criar `src/QueryBuilder.jl`:

```julia
"""
    module QueryBuilderModule

Query builder composável usando o pipe operator.
Constrói queries SQL de forma segura sem escrever SQL cru.

Uso:
    from("users") |> where("active = ?", [1]) |> limit(10) |> all
"""
module QueryBuilderModule

using ..Repo

export from, where, select, limit, offset, order_by, to_sql, all, Query

"""
    struct Query

Estrutura imutável que representa uma query em construção.
Cada operação retorna uma NOVA Query (imutabilidade funcional).
"""
struct Query
    table::String
    columns::Vector{String}
    conditions::Vector{String}
    params::Vector{Any}
    order::String
    limit_val::Int
    offset_val::Int
end

"""
    from(table::String) :: Query

Cria uma query base para a tabela especificada.
"""
function from(table::String)::Query
    return Query(table, String[], String[], Any[], "", -1, -1)
end

"""
    select(q::Query, cols::Vector{String}) :: Query

Define quais colunas selecionar. Retorna nova Query.
"""
function select(q::Query, cols::Vector{String})::Query
    return Query(q.table, cols, q.conditions, q.params, q.order, q.limit_val, q.offset_val)
end

"""
    where(q::Query, condition::String, params::Vector=[]) :: Query

Adiciona uma condição WHERE. Acumula com AND. Retorna nova Query.
"""
function where(q::Query, condition::String, params::Vector=Any[])::Query
    new_conditions = [q.conditions..., condition]
    new_params = [q.params..., params...]
    return Query(q.table, q.columns, new_conditions, new_params, q.order, q.limit_val, q.offset_val)
end

"""
    order_by(q::Query, clause::String) :: Query

Define a cláusula ORDER BY. Retorna nova Query.
"""
function order_by(q::Query, clause::String)::Query
    return Query(q.table, q.columns, q.conditions, q.params, clause, q.limit_val, q.offset_val)
end

"""
    limit(q::Query, n::Int) :: Query

Define o LIMIT. Retorna nova Query.
"""
function limit(q::Query, n::Int)::Query
    return Query(q.table, q.columns, q.conditions, q.params, q.order, n, q.offset_val)
end

"""
    offset(q::Query, n::Int) :: Query

Define o OFFSET. Retorna nova Query.
"""
function offset(q::Query, n::Int)::Query
    return Query(q.table, q.columns, q.conditions, q.params, q.order, q.limit_val, n)
end

"""
    to_sql(q::Query) :: Tuple{String, Vector{Any}}

Converte a Query em uma tupla (sql_string, params_vector).
Função pura: não acessa o banco.
"""
function to_sql(q::Query)::Tuple{String, Vector{Any}}
    # SELECT
    cols = isempty(q.columns) ? "*" : join(q.columns, ", ")
    sql = "SELECT $cols FROM $(q.table)"

    # WHERE
    if !isempty(q.conditions)
        sql *= " WHERE " * join(q.conditions, " AND ")
    end

    # ORDER BY
    if !isempty(q.order)
        sql *= " ORDER BY $(q.order)"
    end

    # LIMIT
    if q.limit_val >= 0
        sql *= " LIMIT $(q.limit_val)"
    end

    # OFFSET
    if q.offset_val >= 0
        sql *= " OFFSET $(q.offset_val)"
    end

    return (sql, q.params)
end

"""
    all(q::Query) :: Vector

Executa a query no banco (via Repo) e retorna os resultados.
Esta é a ÚNICA função com side-effect neste módulo.
"""
function all(q::Query)::Vector
    sql, params = to_sql(q)
    return Repo.query(sql, params)
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - `include("QueryBuilder.jl")` após Repo.jl include
  - `using .QueryBuilderModule`
  - Exportar: `export from, where, select, limit, offset, order_by, to_sql`
  - NOTA: não exportar `all` para evitar conflito com `Base.all`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Tarefa 2.3: Associations (has_many, belongs_to) com Preload

**Objetivo**: Declarar relações entre modelos e carregar associações com query eficiente (sem N+1).

**Arquivos envolvidos**:
- `src/Association.jl` (NOVO)
- `src/Suindara.jl` (EDITAR)
- `test/test_association.jl` (NOVO)
- `test/runtests.jl` (EDITAR)

### RED

- [ ] Criar `test/test_association.jl`:

```julia
using Test
using Suindara

@testset "Associations" begin
    # Setup: banco com duas tabelas relacionadas
    Suindara.Repo.connect(":memory:")
    Suindara.Repo.execute("CREATE TABLE authors (id INTEGER PRIMARY KEY, name TEXT)")
    Suindara.Repo.execute("CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, author_id INTEGER)")
    Suindara.Repo.execute("INSERT INTO authors (id, name) VALUES (1, 'Machado')")
    Suindara.Repo.execute("INSERT INTO authors (id, name) VALUES (2, 'Clarice')")
    Suindara.Repo.execute("INSERT INTO books (title, author_id) VALUES ('Dom Casmurro', 1)")
    Suindara.Repo.execute("INSERT INTO books (title, author_id) VALUES ('Quincas Borba', 1)")
    Suindara.Repo.execute("INSERT INTO books (title, author_id) VALUES ('A Hora da Estrela', 2)")

    Assoc = Suindara.AssociationModule

    @testset "preload_has_many carrega filhos" begin
        authors = Suindara.Repo.query("SELECT * FROM authors ORDER BY id")
        result = Assoc.preload_has_many(authors, :books, "books", "author_id")

        # Machado tem 2 livros
        @test length(result[1][:books]) == 2
        # Clarice tem 1 livro
        @test length(result[2][:books]) == 1
    end

    @testset "preload_belongs_to carrega pai" begin
        books = Suindara.Repo.query("SELECT * FROM books ORDER BY id")
        result = Assoc.preload_belongs_to(books, :author, "authors", "author_id")

        @test result[1][:author].name == "Machado"
        @test result[3][:author].name == "Clarice"
    end

    @testset "preload_has_many com lista vazia" begin
        result = Assoc.preload_has_many([], :books, "books", "author_id")
        @test isempty(result)
    end

    @testset "preload_belongs_to com FK nulo" begin
        Suindara.Repo.execute("INSERT INTO books (title, author_id) VALUES ('Orfão', NULL)")
        books = Suindara.Repo.query("SELECT * FROM books WHERE title = ?", ["Orfão"])
        result = Assoc.preload_belongs_to(books, :author, "authors", "author_id")
        @test result[1][:author] === nothing
    end

end
```

- [ ] Adicionar `include("test_association.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM. RED ✅

### GREEN

- [ ] Criar `src/Association.jl`:

```julia
"""
    module AssociationModule

Funções para carregar associações (has_many, belongs_to) de forma eficiente,
evitando problemas de N+1 queries.

Todas as funções de preload fazem exatamente 1 query adicional, independente
do número de registros pai.
"""
module AssociationModule

using ..Repo

export preload_has_many, preload_belongs_to

"""
    extract_ids(rows, key::Symbol) :: Vector

Extrai valores de uma coluna, filtrando nulos. Função pura.
"""
function extract_ids(rows::Vector, key::Symbol)::Vector
    ids = []
    for row in rows
        val = get(Dict(pairs(row)), key, nothing)
        if val !== nothing
            push!(ids, val)
        end
    end
    return unique(ids)
end

"""
    build_lookup(rows, key::Symbol) :: Dict

Cria Dict[valor_da_chave => row] para lookup O(1). Função pura.
"""
function build_lookup(rows::Vector, key::Symbol)::Dict
    lookup = Dict()
    for row in rows
        k = getproperty(row, key)
        lookup[k] = row
    end
    return lookup
end

"""
    build_group(rows, key::Symbol) :: Dict

Agrupa rows por valor de uma chave. Retorna Dict[valor => [rows...]]. Função pura.
"""
function build_group(rows::Vector, key::Symbol)::Dict
    groups = Dict()
    for row in rows
        k = getproperty(row, key)
        if !haskey(groups, k)
            groups[k] = []
        end
        push!(groups[k], row)
    end
    return groups
end

"""
    preload_has_many(parents, assoc_name, child_table, foreign_key, parent_key=:id)

Carrega filhos (1 query) e anexa como assoc_name em cada parent.
Retorna vetor de Dicts com todos os campos originais + assoc_name.
"""
function preload_has_many(parents::Vector, assoc_name::Symbol, child_table::String, foreign_key::String; parent_key::Symbol=:id)
    if isempty(parents)
        return []
    end

    parent_ids = extract_ids(parents, parent_key)
    if isempty(parent_ids)
        return [merge(Dict(pairs(p)), Dict(assoc_name => [])) for p in parents]
    end

    placeholders = join(["?" for _ in parent_ids], ",")
    children = Repo.query("SELECT * FROM $child_table WHERE $foreign_key IN ($placeholders)", parent_ids)

    groups = build_group(children, Symbol(foreign_key))

    result = []
    for parent in parents
        pid = getproperty(parent, parent_key)
        kids = get(groups, pid, [])
        push!(result, merge(Dict(pairs(parent)), Dict(assoc_name => kids)))
    end
    return result
end

"""
    preload_belongs_to(children, assoc_name, parent_table, foreign_key, parent_key=:id)

Carrega pais (1 query) e anexa como assoc_name em cada child.
"""
function preload_belongs_to(children_rows::Vector, assoc_name::Symbol, parent_table::String, foreign_key::String; parent_key::Symbol=:id)
    if isempty(children_rows)
        return []
    end

    fk_ids = extract_ids(children_rows, Symbol(foreign_key))
    if isempty(fk_ids)
        return [merge(Dict(pairs(c)), Dict(assoc_name => nothing)) for c in children_rows]
    end

    pk_col = String(parent_key)
    placeholders = join(["?" for _ in fk_ids], ",")
    parents = Repo.query("SELECT * FROM $parent_table WHERE $pk_col IN ($placeholders)", fk_ids)

    lookup = build_lookup(parents, parent_key)

    result = []
    for child in children_rows
        fk_val = get(Dict(pairs(child)), Symbol(foreign_key), nothing)
        parent = fk_val !== nothing ? get(lookup, fk_val, nothing) : nothing
        push!(result, merge(Dict(pairs(child)), Dict(assoc_name => parent)))
    end
    return result
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - `include("Association.jl")` após QueryBuilder.jl
  - `using .AssociationModule`
  - `export preload_has_many, preload_belongs_to`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Tarefa 2.4: Test Helpers (ConnTest, Factory)

**Objetivo**: Módulo com helpers para facilitar testes de integração.

**Arquivos envolvidos**:
- `src/TestHelpers.jl` (NOVO)
- `src/Suindara.jl` (EDITAR)
- `test/test_test_helpers.jl` (NOVO)
- `test/runtests.jl` (EDITAR)

### RED

- [ ] Criar `test/test_test_helpers.jl`:

```julia
using Test
using Suindara
using HTTP

@testset "Test Helpers" begin
    TH = Suindara.TestHelpersModule

    @testset "build_conn cria GET request" begin
        conn = TH.build_conn("GET", "/users")
        @test conn isa Conn
        @test conn.request.method == "GET"
        @test conn.request.target == "/users"
    end

    @testset "build_conn cria POST com JSON body" begin
        conn = TH.build_conn("POST", "/users", json=Dict("name" => "Ana"))
        @test conn.request.method == "POST"
        body_str = String(copy(conn.request.body))
        @test contains(body_str, "Ana")
        @test any(h -> contains(last(h), "application/json"), conn.request.headers)
    end

    @testset "build_conn cria PUT com params" begin
        conn = TH.build_conn("PUT", "/users/1", json=Dict("name" => "Updated"))
        @test conn.request.method == "PUT"
    end

    @testset "assert_status verifica status do conn" begin
        conn = TH.build_conn("GET", "/")
        conn = resp(conn, 201, "created")
        @test TH.assert_status(conn, 201) == true
        @test TH.assert_status(conn, 200) == false
    end

    @testset "assert_body_contains verifica conteúdo do body" begin
        conn = TH.build_conn("GET", "/")
        conn = resp(conn, 200, "Hello World")
        @test TH.assert_body_contains(conn, "Hello") == true
        @test TH.assert_body_contains(conn, "Bye") == false
    end

    @testset "setup_test_db cria banco in-memory" begin
        TH.setup_test_db()
        # Deve conseguir executar SQL nele
        Suindara.Repo.execute("CREATE TABLE helpers_test (id INTEGER PRIMARY KEY)")
        @test true
    end

end
```

- [ ] Adicionar `include("test_test_helpers.jl")` ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM. RED ✅

### GREEN

- [ ] Criar `src/TestHelpers.jl`:

```julia
"""
    module TestHelpersModule

Helpers para facilitar testes de integração em aplicações Suindara.
Inspirado no Phoenix.ConnTest.
"""
module TestHelpersModule

using ..ConnModule
using ..Repo
using HTTP
using JSON3

export build_conn, assert_status, assert_body_contains, setup_test_db

"""
    build_conn(method, path; json=nothing) :: Conn

Cria um Conn de teste com HTTP.Request configurado.
Se `json` é fornecido, serializa como body JSON e adiciona Content-Type.
"""
function build_conn(method::String, path::String; json=nothing)::Conn
    headers = Pair{String,String}[]
    body = ""

    if json !== nothing
        body = JSON3.write(json)
        push!(headers, "Content-Type" => "application/json")
    end

    req = HTTP.Request(method, path, headers, body)
    return Conn(req)
end

"""
    assert_status(conn::Conn, expected::Int) :: Bool

Retorna true se conn.status == expected.
"""
function assert_status(conn::Conn, expected::Int)::Bool
    return conn.status == expected
end

"""
    assert_body_contains(conn::Conn, substring::String) :: Bool

Retorna true se conn.resp_body contém a substring.
"""
function assert_body_contains(conn::Conn, substring::String)::Bool
    return contains(conn.resp_body, substring)
end

"""
    setup_test_db()

Conecta a um banco SQLite in-memory para testes isolados.
"""
function setup_test_db()
    Repo.connect(":memory:")
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - `include("TestHelpers.jl")` após Association.jl
  - `using .TestHelpersModule`
  - `export build_conn, assert_status, assert_body_contains, setup_test_db`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Tarefa 2.5: Error Pages com Debug em Dev Mode

**Objetivo**: Em modo dev, mostrar stack trace e detalhes do erro. Em modo prod, mostrar "Internal Server Error" genérico.

**Arquivos envolvidos**:
- `src/ErrorHandler.jl` (NOVO)
- `src/Suindara.jl` (EDITAR)
- `test/test_error_handler.jl` (NOVO)
- `test/runtests.jl` (EDITAR)

### RED

- [ ] Criar `test/test_error_handler.jl`:

```julia
using Test
using Suindara

@testset "Error Handler" begin
    EH = Suindara.ErrorHandlerModule

    @testset "is_dev_mode detecta ambiente" begin
        @test EH.is_dev_mode() isa Bool
    end

    @testset "format_error_dev inclui detalhes" begin
        try
            error("test boom")
        catch e
            bt = catch_backtrace()
            body = EH.format_error_dev(e, bt)
            @test contains(body, "test boom")
            @test contains(body, "ErrorException")
        end
    end

    @testset "format_error_prod é genérico" begin
        try
            error("secret")
        catch e
            bt = catch_backtrace()
            body = EH.format_error_prod(e, bt)
            @test contains(body, "Internal Server Error")
            @test !contains(body, "secret")
        end
    end

    @testset "format_error despacha por modo" begin
        try
            error("dispatch test")
        catch e
            bt = catch_backtrace()
            body = EH.format_error(e, bt)
            @test body isa String
            @test length(body) > 0
        end
    end

end
```

- [ ] Adicionar ao `test/runtests.jl`.
- [ ] Rodar testes. FALHAM. RED ✅

### GREEN

- [ ] Criar `src/ErrorHandler.jl`:

```julia
"""
    module ErrorHandlerModule

Formatação de erros para desenvolvimento e produção.
Em dev: mostra exceção, backtrace, request info.
Em prod: mostra mensagem genérica.
"""
module ErrorHandlerModule

export is_dev_mode, format_error, format_error_dev, format_error_prod

"""
    is_dev_mode() :: Bool

Retorna true se SUINDARA_ENV != "prod". Default: dev mode.
"""
function is_dev_mode()::Bool
    env = get(ENV, "SUINDARA_ENV", "dev")
    return env != "prod"
end

"""
    format_error_dev(e::Exception, bt) :: String

Formata erro para modo dev com detalhes completos.
"""
function format_error_dev(e::Exception, bt)::String
    io = IOBuffer()
    println(io, "=== SUINDARA DEBUG ERROR ===")
    println(io, "Exception Type: $(typeof(e))")
    println(io, "Message: $(sprint(showerror, e))")
    println(io, "")
    println(io, "--- Backtrace ---")
    for frame in stacktrace(bt)
        println(io, "  $(frame)")
    end
    println(io, "=== END DEBUG ===")
    return String(take!(io))
end

"""
    format_error_prod(e::Exception, bt) :: String

Formata erro para modo prod. NÃO vaza informações internas.
"""
function format_error_prod(::Exception, bt)::String
    return "Internal Server Error"
end

"""
    format_error(e::Exception, bt) :: String

Despacha para format_error_dev ou format_error_prod baseado no modo.
"""
function format_error(e::Exception, bt)::String
    if is_dev_mode()
        return format_error_dev(e, bt)
    else
        return format_error_prod(e, bt)
    end
end

end # module
```

- [ ] Editar `src/Suindara.jl`:
  - `include("ErrorHandler.jl")` após TestHelpers.jl
  - `using .ErrorHandlerModule`
  - `export format_error, is_dev_mode`

- [ ] Rodar testes. TODOS passam. GREEN ✅

### REFACTOR

- [ ] Rodar testes → DONE ✅

---

## Checklist Final da Fase 2

- [ ] Rodar `julia --project=. test/runtests.jl` — TODOS os testes passam
- [ ] Atualizar `Project.toml` version para `0.5.0`
- [ ] Commitar: `git add . && git commit -m "v0.5.0: Phase 2 — Data Maturity (Adapter, QueryBuilder, Associations, TestHelpers, ErrorHandler)"`
