module MigrationModule

using ..Repo
using ..ConnModule
using Dates

export migrate, rollback, create_table, add_column, drop_table, execute

const MIGRATIONS_TABLE = "schema_migrations"

# --- DSL Helpers (Syntax Sugar) ---

"""
    create_table(name::String, columns::Vector{String})
Helper to generate CREATE TABLE SQL.
Example: `create_table("users", ["id INTEGER PRIMARY KEY", "name TEXT"])`
"""
function create_table(name::String, columns::Vector{String})
    cols_sql = join(columns, ", ")
    sql = "CREATE TABLE IF NOT EXISTS $name ($cols_sql)"
    Repo.execute(sql)
    println("   -> Created table $name")
end

"""
    drop_table(name::String)
Drops a table.
"""
function drop_table(name::String)
    Repo.execute("DROP TABLE IF EXISTS $name")
    println("   -> Dropped table $name")
end

"""
    add_column(table::String, col_def::String)
Adds a column to an existing table.
"""
function add_column(table::String, col_def::String)
    Repo.execute("ALTER TABLE $table ADD COLUMN $col_def")
    println("   -> Added column to $table: $col_def")
end

"""
    execute(sql::String)
Direct SQL execution wrapper for migrations.
"""
function execute(sql::String)
    Repo.execute(sql)
end

# --- Internal Helpers ---

function _run_step(m::Module, step::Symbol)
    if isdefined(m, step)
        # We use getproperty inside the invoked world age to avoid warnings
        f = getproperty(m, step)
        f()
        return true
    end
    return false
end

# --- Core Logic ---

function ensure_migration_table()
    Repo.execute("""
    CREATE TABLE IF NOT EXISTS $MIGRATIONS_TABLE (
        version TEXT PRIMARY KEY,
        applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    """)
end

function get_applied_versions()
    ensure_migration_table()
    # Materialize everything and let the stmt die
    versions = Set{String}()
    rows = Repo.query("SELECT version FROM $MIGRATIONS_TABLE ORDER BY version ASC")
    for r in rows
        push!(versions, r.version)
    end
    return versions
end

"""
    migrate(migrations_dir::String="db/migrations")

Scans the directory for migration files, checks which ones haven't been applied,
and executes their `up()` function.
"""
function migrate(migrations_dir::String="db/migrations")
    migrations_dir = abspath(migrations_dir)
    if !isdir(migrations_dir)
        mkpath(migrations_dir)
        println("Created migrations directory: $migrations_dir")
        return
    end

    applied = get_applied_versions()
    
    # List all .jl files
    files = filter(f -> endswith(f, ".jl"), readdir(migrations_dir))
    sort!(files) # Ensure chronological order by timestamp prefix
    
    pending_count = 0
    
    for file in files
        # Extract version from filename (assuming YYYYMMDDHHMMSS_name.jl)
        version = split(file, "_")[1]
        
        if version in applied
            continue
        end
        
        println("== Migrating: $file ==")
        full_path = joinpath(migrations_dir, file)
        
        try
            # REMOVED Repo.transaction wrapper to avoid SQLite Locking issues with DDL
            
            m = Module()
            Core.eval(m, :(using Suindara.MigrationModule))
            Base.include(m, full_path)
            
            # Use invokelatest via helper to access m.up in the correct world age
            success = Base.invokelatest(_run_step, m, :up)
            
            if success
                # Record success manually
                Repo.execute("INSERT INTO $MIGRATIONS_TABLE (version) VALUES (?)", [version])
                println("== Migrated: $file (Version $version) ==\n")
                pending_count += 1
            else
                error("Migration $file does not define an `up()` function.")
            end
        catch e
            println("!! Failed to migrate $file !!")
            rethrow(e)
        end
    end
    
    if pending_count == 0
        println("Migrations are up to date.")
    end
end

"""
    rollback(migrations_dir::String="db/migrations")
Undoes the LAST applied migration.
"""
function rollback(migrations_dir::String="db/migrations")
    migrations_dir = abspath(migrations_dir)
    applied = sort(collect(get_applied_versions()))
    
    if isempty(applied)
        println("No migrations to rollback.")
        return
    end
    
    last_version = last(applied)
    
    files = filter(f -> startswith(f, last_version), readdir(migrations_dir))
    if isempty(files)
        error("Found version $last_version in DB but file is missing from disk.")
    end
    
    file = first(files)
    full_path = joinpath(migrations_dir, file)
    
    println("== Rolling back: $file ==")
    
    try
        # REMOVED Repo.transaction wrapper here as well
        
        m = Module()
        Core.eval(m, :(using Suindara.MigrationModule))
        Base.include(m, full_path)
        
        success = Base.invokelatest(_run_step, m, :down)
        
        if success
            Repo.execute("DELETE FROM $MIGRATIONS_TABLE WHERE version = ?", [last_version])
            println("== Rolled back: $file ==\n")
        else
            error("Migration $file does not define a `down()` function.")
        end
    catch e
        println("!! Failed to rollback $file !!")
        rethrow(e)
    end
end

end # module
