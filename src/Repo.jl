module Repo

using SQLite
using DBInterface
using ..ChangesetModule

export connect, query, execute, insert, update, delete, get_one, transaction

# Thread-safe database connection holder
const _DB = Ref{Union{SQLite.DB, Nothing}}(nothing)
const _DB_LOCK = ReentrantLock()

"""
    connect(path::String)
Connects to the SQLite database at the given path.
"""
function connect(path::String)
    lock(_DB_LOCK) do
        _DB[] = SQLite.DB(path)
    end
end

"""
    get_db()
Internal function to safely retrieve the database connection.
"""
function get_db()
    db = _DB[]
    if db === nothing
        error("Database not connected. Call Repo.connect(path) first.")
    end
    return db
end

"""
    query(sql::String, params=())
Executes a SQL query and returns the result as an iterable of rows. Thread-safe.
"""
function query(sql::String, params=())
    lock(_DB_LOCK) do
        return DBInterface.execute(get_db(), sql, params)
    end
end

"""
    execute(sql::String, params=())
Executes a SQL statement. Thread-safe.
"""
function execute(sql::String, params=())
    lock(_DB_LOCK) do
        DBInterface.execute(get_db(), sql, params)
    end
end

"""
    transaction(f::Function)
Executes the function `f` within a database transaction.
"""
function transaction(f::Function)
    lock(_DB_LOCK) do
        db = get_db()
        SQLite.transaction(db) do
            f()
        end
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