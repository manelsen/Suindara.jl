"""
    module SuindaraPostgresExt

Extension module loaded automatically when `LibPQ` is present.
Implements the PostgresAdapter.
"""
module SuindaraPostgresExt

using LibPQ
using Suindara.RepoAdapterModule

"""
    mutable struct PostgresAdapter <: AbstractAdapter

Adapter PostgreSQL com pool de conexões.
"""
mutable struct PostgresAdapter <: AbstractAdapter
    pool::Channel{LibPQ.Connection}
    connection_string::String

    function PostgresAdapter()
        new(Channel{LibPQ.Connection}(32), "")
    end
end

function __init__()
    register_adapter!(:postgres, PostgresAdapter)
end

# --- Interface implementation ---

function RepoAdapterModule.adapter_connect!(adapter::PostgresAdapter, connection_string::String)
    adapter.connection_string = connection_string
    pool_size = min(4, Sys.CPU_THREADS)

    # Limpar pool existente
    while isready(adapter.pool)
        conn = take!(adapter.pool)
        close(conn)
    end

    for _ in 1:pool_size
        conn = LibPQ.Connection(connection_string)
        put!(adapter.pool, conn)
    end
end

function RepoAdapterModule.adapter_get_conn(adapter::PostgresAdapter)
    txn_conn = get(task_local_storage(), :suindara_txn_conn, nothing)
    if txn_conn !== nothing
        return txn_conn
    end

    if !isready(adapter.pool) && adapter.connection_string == ""
        error("Database not connected. Call Repo.connect(connstring, adapter=:postgres) first.")
    end

    start_time = time()
    while !isready(adapter.pool)
        if (time() - start_time) * 1000 > 5000
            error("Connection pool timeout after 5000ms")
        end
        yield()
    end

    return take!(adapter.pool)
end

function RepoAdapterModule.adapter_release_conn!(adapter::PostgresAdapter, conn)
    txn_conn = get(task_local_storage(), :suindara_txn_conn, nothing)
    if txn_conn === conn
        return
    end
    put!(adapter.pool, conn)
end

"""
    _pg_convert_sql(sql) — Converte `?` para `\$1, \$2, ...`
"""
function _pg_convert_sql(sql::String)::String
    return convert_placeholders(sql, :dollar)
end

function RepoAdapterModule.adapter_query(adapter::PostgresAdapter, sql::String, params=())::Vector
    conn = RepoAdapterModule.adapter_get_conn(adapter)
    try
        pg_sql = _pg_convert_sql(sql)
        str_params = [string(p) for p in params]
        result = LibPQ.execute(conn, pg_sql, str_params)

        # Materializa para Vector{NamedTuple}
        columns = LibPQ.column_names(result)
        rows = Vector{NamedTuple}()
        for row_idx in 1:LibPQ.num_rows(result)
            vals = Dict{Symbol, Any}()
            for (col_idx, col_name) in enumerate(columns)
                vals[Symbol(col_name)] = LibPQ.getvalue(result, row_idx, col_idx)
            end
            push!(rows, NamedTuple{Tuple(keys(vals)...)}(values(vals)))
        end
        return rows
    finally
        RepoAdapterModule.adapter_release_conn!(adapter, conn)
    end
end

function RepoAdapterModule.adapter_execute!(adapter::PostgresAdapter, sql::String, params=())
    conn = RepoAdapterModule.adapter_get_conn(adapter)
    try
        pg_sql = _pg_convert_sql(sql)
        str_params = [string(p) for p in params]
        LibPQ.execute(conn, pg_sql, str_params)
    finally
        RepoAdapterModule.adapter_release_conn!(adapter, conn)
    end
end

function RepoAdapterModule.adapter_transaction(adapter::PostgresAdapter, f::Function)
    conn = RepoAdapterModule.adapter_get_conn(adapter)
    try
        task_local_storage(:suindara_txn_conn, conn)
        LibPQ.execute(conn, "BEGIN")
        try
            result = f()
            LibPQ.execute(conn, "COMMIT")
            return result
        catch e
            LibPQ.execute(conn, "ROLLBACK")
            rethrow(e)
        end
    finally
        delete!(task_local_storage(), :suindara_txn_conn)
        RepoAdapterModule.adapter_release_conn!(adapter, conn)
    end
end

function RepoAdapterModule.adapter_sql_type(::PostgresAdapter, type::Symbol)::String
    if type == :string
        return "VARCHAR(255)"
    elseif type == :text
        return "TEXT"
    elseif type == :integer
        return "INTEGER"
    elseif type == :float
        return "DOUBLE PRECISION"
    elseif type == :boolean
        return "BOOLEAN"
    elseif type == :datetime
        return "TIMESTAMP"
    elseif type == :date
        return "DATE"
    elseif type == :binary
        return "BYTEA"
    else
        error("Unsupported type for Postgres: $type")
    end
end

end # module
