module Repo

using SQLite
using DBInterface
using ..ChangesetModule

export connect, query, execute, insert, update, delete, get_one, transaction

# Thread-safe database connection holder
const _POOL = Channel{SQLite.DB}(32)
const _DB_PATH = Ref{String}("")

"""
    connect(path::String)
Connects to the SQLite database at the given path with WAL mode enabled and initializes the pool.
"""
function connect(path::String)
    _DB_PATH[] = path
    pool_size = min(4, Sys.CPU_THREADS)
    
    # Limpar canal se já existir
    while isready(_POOL)
        take!(_POOL)
    end
    
    for _ in 1:pool_size
        db = SQLite.DB(path)
        # WAL mode and busy timeout
        try
            DBInterface.execute(db, "PRAGMA journal_mode=WAL;")
            DBInterface.execute(db, "PRAGMA synchronous=NORMAL;")
            DBInterface.execute(db, "PRAGMA wal_autocheckpoint=1000;")
            DBInterface.execute(db, "PRAGMA busy_timeout=5000;")
        catch e
            @warn "Failed to set PRAGMA: $e"
        end
        put!(_POOL, db)
    end
end

"""
    get_conn(timeout_ms::Int=5000)
Retrieves a database connection from the pool.
"""
function get_conn(timeout_ms::Int=5000)
    if !isready(_POOL) && _DB_PATH[] == ""
        error("Database not connected. Call Repo.connect(path) first.")
    end
    
    # Simples poll-based timeout para o Channel (ou ConcurrentUtilities.lock se preferir)
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
Returns a connection to the pool.
"""
function release_conn(db)
    put!(_POOL, db)
end

"""
    query(sql::String, params=())
Executes a SQL query and returns the result as an iterable of rows.
"""
function query(sql::String, params=())
    db = get_conn()
    try
        return DBInterface.execute(db, sql, params)
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
        DBInterface.execute(db, sql, params)
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
        SQLite.transaction(db) do
            f()
        end
    finally
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