module Repo

using ..RepoAdapterModule
using ..ChangesetModule

export connect, query, execute, insert, update, delete, get_one, transaction

# Adapter ativo — configurado por connect()
const _ADAPTER = Ref{Union{Nothing, AbstractAdapter}}(nothing)

"""
    _get_adapter() :: AbstractAdapter

Retorna o adapter ativo ou erro se não conectado.
"""
function _get_adapter()::AbstractAdapter
    if _ADAPTER[] === nothing
        error("Database not connected. Call Repo.connect(path) first.")
    end
    return _ADAPTER[]
end

"""
    connect(connection_string::String; adapter::Symbol=:sqlite)

Conecta ao banco usando o adapter especificado.
- `:sqlite` → SQLite (default, requer SQLite.jl)
- `:postgres` → PostgreSQL (requer LibPQ.jl)

## Exemplos
    Repo.connect(":memory:")                              # SQLite in-memory
    Repo.connect("myapp.db")                              # SQLite file
    Repo.connect("host=localhost dbname=app"; adapter=:postgres)  # PostgreSQL
"""
function connect(connection_string::String; adapter::Symbol=:sqlite)
    _ADAPTER[] = create_adapter(adapter)
    adapter_connect!(_ADAPTER[], connection_string)
end

"""
    query(sql::String, params=())

Executa SQL query e retorna Vector de NamedTuples.
"""
function query(sql::String, params=())
    return adapter_query(_get_adapter(), sql, params)
end

"""
    execute(sql::String, params=())

Executa SQL statement (INSERT, UPDATE, DELETE, DDL).
"""
function execute(sql::String, params=())
    adapter_execute!(_get_adapter(), sql, params)
end

"""
    transaction(f::Function)

Executa `f()` dentro de uma transação. Rollback automático em caso de erro.
"""
function transaction(f::Function)
    adapter_transaction(_get_adapter(), f)
end

# --- CRUD Operations ---

function validate_name(name::String, type::String="field")
    if !occursin(r"^[a-zA-Z0-9_]+$", name)
        error("Invalid $type name: $name")
    end
end

"""
    insert(ch::Changeset, table::String)

Insere dados de um changeset validado.
"""
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

"""
    update(ch::Changeset, table::String, id::Any; pk::String="id")

Atualiza registro por PK. Só altera campos presentes em `changes`.
"""
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

"""
    delete(table::String, id::Any; pk::String="id")

Deleta registro por PK.
"""
function delete(table::String, id::Any; pk::String="id")
    validate_name(table, "table")
    validate_name(pk, "primary key")

    sql = "DELETE FROM $table WHERE $pk = ?"
    execute(sql, [id])
end

"""
    get_one(table::String, id::Any; pk::String="id")

Busca um registro por PK. Retorna `nothing` se não encontrado.
"""
function get_one(table::String, id::Any; pk::String="id")
    validate_name(table, "table")
    validate_name(pk, "primary key")

    sql = "SELECT * FROM $table WHERE $pk = ? LIMIT 1"
    results = query(sql, [id])

    found = nothing
    for row in results
        found = NamedTuple(Symbol(k) => getproperty(row, Symbol(k)) for k in propertynames(row))
    end
    return found
end

end # module Repo