module Repo

using SQLite
using DBInterface
using ..ChangesetModule

export connect, query, execute, insert, update, delete, get_one, transaction

# Thread-safe database connection holder
const _POOL = Channel{SQLite.DB}(32)
const _DB_PATH = Ref{String}("")

"""
    _exec_and_finalize!(db, sql, params=())
Low-level helper: executes SQL on a raw db handle and finalizes the prepared statement
immediately, so no dangling statements block subsequent operations (e.g. SAVEPOINT).
"""
function _exec_and_finalize!(db::SQLite.DB, sql::String, params=())
    stmt = SQLite.Stmt(db, sql; register=false)
    try
        DBInterface.execute(stmt, params)
    finally
        Base.finalize(stmt)
    end
end

"""
    connect(path::String)
Connects to the SQLite database at the given path with WAL mode enabled and initializes the pool.
"""
function connect(path::String)
    _DB_PATH[] = path
    # In-memory DBs are isolated per connection; use a single conn to share state
    pool_size = path == ":memory:" ? 1 : min(4, Sys.CPU_THREADS)

    # Limpar canal se já existir
    while isready(_POOL)
        take!(_POOL)
    end

    for _ in 1:pool_size
        db = SQLite.DB(path)
        # WAL mode and busy timeout
        try
            _exec_and_finalize!(db, "PRAGMA journal_mode=WAL;")
            _exec_and_finalize!(db, "PRAGMA synchronous=NORMAL;")
            _exec_and_finalize!(db, "PRAGMA wal_autocheckpoint=1000;")
            _exec_and_finalize!(db, "PRAGMA busy_timeout=5000;")
        catch e
            @warn "Failed to set PRAGMA: $e"
        end
        put!(_POOL, db)
    end
end

"""
    get_conn(timeout_ms::Int=5000)
Retrieves a database connection from the pool, or reuses the current transaction connection.
"""
function get_conn(timeout_ms::Int=5000)
    # Reuse connection if inside a transaction on this task
    txn_db = get(task_local_storage(), :suindara_txn_conn, nothing)
    if txn_db !== nothing
        return txn_db
    end

    if !isready(_POOL) && _DB_PATH[] == ""
        error("Database not connected. Call Repo.connect(path) first.")
    end

    start_time = time()
    while !isready(_POOL)
        if (time() - start_time) * 1000 > timeout_ms
            error("Connection pool timeout after $(timeout_ms)ms")
        end
        yield()
    end

    return take!(_POOL)
end

"""
    release_conn(db)
Returns a connection to the pool (skipped if managed by a transaction).
"""
function release_conn(db)
    # Don't return to pool if managed by a transaction
    txn_db = get(task_local_storage(), :suindara_txn_conn, nothing)
    if txn_db === db
        return
    end
    put!(_POOL, db)
end

"""
    query(sql::String, params=())
Executes a SQL query and returns the result as an iterable of rows.
"""
function query(sql::String, params=())
    db = get_conn()
    try
        stmt = SQLite.Stmt(db, sql; register=false)
        try
            result = DBInterface.execute(stmt, params)
            # Materialize rows to release the SQLite statement immediately
            return [NamedTuple(Symbol(k) => getproperty(row, Symbol(k)) for k in propertynames(row)) for row in result]
        finally
            Base.finalize(stmt)
        end
    finally
        release_conn(db)
    end
end

"""
    execute(sql::String, params=())
Executes a SQL statement.
"""
function execute(sql::String, params=())
    db = get_conn()
    try
        _exec_and_finalize!(db, sql, params)
    finally
        release_conn(db)
    end
end

"""
    transaction(f::Function)
Executes the function `f` within a database transaction.
"""
function transaction(f::Function)
    db = get_conn()
    try
        task_local_storage(:suindara_txn_conn, db)
        SQLite.transaction(db) do
            f()
        end
    finally
        delete!(task_local_storage(), :suindara_txn_conn)
        release_conn(db)
    end
end

# --- CRUD Operations ---

function validate_name(name::String, type::String="field")
    if !occursin(r"^[a-zA-Z0-9_]+$", name)
        error("Invalid $type name: $name")
    end
end

"""
    insert(ch::Changeset, table::String)
Inserts data from a changeset.
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
Updates a record by its Primary Key. Only updates fields present in `changes`.
"""
function update(ch::ChangesetModule.Changeset, table::String, id::Any; pk::String="id")
    if !ch.valid
        error("Cannot update invalid changeset")
    end
    
    validate_name(table, "table")
    validate_name(pk, "primary key")
    
    fields = keys(ch.changes) |> collect
    values_list = Any[values(ch.changes)...]
    push!(values_list, id) # Add ID to the end for the WHERE clause
    
    if isempty(fields)
        return ch # No changes to apply
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
Deletes a record by its Primary Key.
"""
function delete(table::String, id::Any; pk::String="id")
    validate_name(table, "table")
    validate_name(pk, "primary key")
    
    sql = "DELETE FROM $table WHERE $pk = ?"
    execute(sql, [id])
end

"""
    get_one(table::String, id::Any; pk::String="id")
Fetches a single row by ID. Returns `nothing` if not found.
"""
function get_one(table::String, id::Any; pk::String="id")
    validate_name(table, "table")
    validate_name(pk, "primary key")
    
    sql = "SELECT * FROM $table WHERE $pk = ? LIMIT 1"
    results = query(sql, [id])
    
    # Consume the result fully (it's max 1 row)
    found = nothing
    for row in results
        # Materialize to NamedTuple to survive iterator exhaustion
        found = NamedTuple(Symbol(k) => getproperty(row, Symbol(k)) for k in propertynames(row))
    end
    return found
end

end # module Repo