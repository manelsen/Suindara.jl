"""
    SQLiteAdapter — Adapter concreto para SQLite via SQLite.jl.

Extrai toda a lógica SQLite-específica do antigo Repo.jl:
pool via Channel{SQLite.DB}, WAL mode, prepared statements, SQLite.transaction.
"""

using .RepoAdapterModule
using SQLite
using DBInterface

"""
    mutable struct SQLiteAdapter <: AbstractAdapter

Adapter SQLite com pool de conexões thread-safe.
"""
mutable struct SQLiteAdapter <: AbstractAdapter
    pool::Channel{SQLite.DB}
    db_path::String

    function SQLiteAdapter()
        new(Channel{SQLite.DB}(32), "")
    end
end

# Registra no factory
register_adapter!(:sqlite, SQLiteAdapter)

# --- Helpers internos ---

"""
    _sqlite_exec_finalize!(db, sql, params) — Executa e finaliza stmt imediatamente.
"""
function _sqlite_exec_finalize!(db::SQLite.DB, sql::String, params=())
    stmt = SQLite.Stmt(db, sql; register=false)
    try
        DBInterface.execute(stmt, params)
    finally
        Base.finalize(stmt)
    end
end

# --- Interface implementation ---

function RepoAdapterModule.adapter_connect!(adapter::SQLiteAdapter, connection_string::String)
    adapter.db_path = connection_string
    pool_size = connection_string == ":memory:" ? 1 : min(4, Sys.CPU_THREADS)

    # Limpar pool existente
    while isready(adapter.pool)
        take!(adapter.pool)
    end

    for _ in 1:pool_size
        db = SQLite.DB(connection_string)
        try
            _sqlite_exec_finalize!(db, "PRAGMA journal_mode=WAL;")
            _sqlite_exec_finalize!(db, "PRAGMA synchronous=NORMAL;")
            _sqlite_exec_finalize!(db, "PRAGMA wal_autocheckpoint=1000;")
            _sqlite_exec_finalize!(db, "PRAGMA busy_timeout=5000;")
        catch e
            @warn "Failed to set PRAGMA: $e"
        end
        put!(adapter.pool, db)
    end
end

function RepoAdapterModule.adapter_get_conn(adapter::SQLiteAdapter)
    # Reutiliza conexão se dentro de transação
    txn_db = get(task_local_storage(), :suindara_txn_conn, nothing)
    if txn_db !== nothing
        return txn_db
    end

    if !isready(adapter.pool) && adapter.db_path == ""
        error("Database not connected. Call Repo.connect(path) first.")
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

function RepoAdapterModule.adapter_release_conn!(adapter::SQLiteAdapter, db)
    txn_db = get(task_local_storage(), :suindara_txn_conn, nothing)
    if txn_db === db
        return
    end
    put!(adapter.pool, db)
end

function RepoAdapterModule.adapter_query(adapter::SQLiteAdapter, sql::String, params=())::Vector
    db = adapter_get_conn(adapter)
    try
        stmt = SQLite.Stmt(db, sql; register=false)
        try
            result = DBInterface.execute(stmt, params)
            return [NamedTuple(Symbol(k) => getproperty(row, Symbol(k)) for k in propertynames(row)) for row in result]
        finally
            Base.finalize(stmt)
        end
    finally
        adapter_release_conn!(adapter, db)
    end
end

function RepoAdapterModule.adapter_execute!(adapter::SQLiteAdapter, sql::String, params=())
    db = adapter_get_conn(adapter)
    try
        _sqlite_exec_finalize!(db, sql, params)
    finally
        adapter_release_conn!(adapter, db)
    end
end

function RepoAdapterModule.adapter_transaction(adapter::SQLiteAdapter, f::Function)
    db = adapter_get_conn(adapter)
    try
        task_local_storage(:suindara_txn_conn, db)
        SQLite.transaction(db) do
            f()
        end
    finally
        delete!(task_local_storage(), :suindara_txn_conn)
        adapter_release_conn!(adapter, db)
    end
end

function RepoAdapterModule.adapter_sql_type(::SQLiteAdapter, type::Symbol)::String
    if type == :string || type == :text
        return "TEXT"
    elseif type == :integer
        return "INTEGER"
    elseif type == :float
        return "REAL"
    elseif type == :boolean
        return "INTEGER" # SQLite uses 0/1
    elseif type == :datetime
        return "DATETIME"
    elseif type == :date
        return "DATE"
    elseif type == :binary
        return "BLOB"
    else
        error("Unsupported type for SQLite: $type")
    end
end
