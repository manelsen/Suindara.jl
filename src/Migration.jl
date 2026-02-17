module MigrationModule

using ..Repo
using ..RepoAdapterModule
using Dates

export migrate, rollback, create_table, add_column, drop_table, execute, add, timestamps, add_index

const MIGRATIONS_TABLE = "schema_migrations"

# --- Schema Builder for DSL ---

mutable struct SchemaBuilder
    table_name::String
    columns::Vector{String}
    
    SchemaBuilder(name::String) = new(name, String[])
end

# Thread-local storage key
const BUILDER_KEY = :suindara_migration_builder

"""
    create_table(block::Function, name::Symbol)
    
DSL to create a table.
Example:
```julia
create_table(:users) do
    add(:name, :string; null=false)
    # ...
end
```
"""
function create_table(block::Function, name::Symbol)
    table_name = string(name)
    builder = SchemaBuilder(table_name)
    task_local_storage(BUILDER_KEY, builder)
    
    try
        block() # Executes add() calls which push to builder
        
        cols_sql = join(builder.columns, ", ")
        sql = "CREATE TABLE IF NOT EXISTS $table_name ($cols_sql)"
        Repo.execute(sql)
        println("   -> Created table $table_name")
    finally
        delete!(task_local_storage(), BUILDER_KEY)
    end
end

"""
    add(name::Symbol, type::Symbol; opts...)
    
Adds a column definition to the current table builder.
Options:
- `primary_key::Bool`: PRIMARY KEY
- `null::Bool`: NULL or NOT NULL (default: true)
- `default::Any`: DEFAULT value
- `unique::Bool`: UNIQUE constraint
"""
function add(name::Symbol, type::Symbol; opts...)
    if !haskey(task_local_storage(), BUILDER_KEY)
        error("add() must be called inside a create_table block")
    end
    builder = task_local_storage(BUILDER_KEY)
   
    adapter = Repo._get_adapter()
    sql_type = RepoAdapterModule.adapter_sql_type(adapter, type)
    
    col_def = "$name $sql_type"
    
    # Options handling
    opts_dict = Dict(opts)
    
    if get(opts_dict, :primary_key, false)
        col_def *= " PRIMARY KEY"
    end
    
    if !get(opts_dict, :null, true)
        col_def *= " NOT NULL"
    end
    
    if haskey(opts_dict, :unique) && opts_dict[:unique]
        col_def *= " UNIQUE"
    end
    
    if haskey(opts_dict, :default)
        val = opts_dict[:default]
        default_str = val isa String ? "'$val'" : string(val)
        col_def *= " DEFAULT $default_str"
    end
    
    push!(builder.columns, col_def)
end

"""
    timestamps(; opts...)
    
Adds `inserted_at` and `updated_at` columns.
"""
function timestamps(; opts...)
    add(:inserted_at, :datetime; null=false, default="CURRENT_TIMESTAMP", opts...)
    add(:updated_at, :datetime; null=false, default="CURRENT_TIMESTAMP", opts...)
end

"""
    add_index(table::Symbol, columns::Union{Symbol, Vector{Symbol}}; unique::Bool=false)
    
Creates an index.
"""
function add_index(table::Symbol, columns::Union{Symbol, Vector{Symbol}}; unique::Bool=false)
    table_str = string(table)
    cols = columns isa Symbol ? [columns] : columns
    cols_str = join(cols, "_")
    index_name = "idx_$(table_str)_$(cols_str)"
    
    cols_list = join(cols, ", ")
    unique_str = unique ? "UNIQUE " : ""
    
    sql = "CREATE $(unique_str)INDEX IF NOT EXISTS $index_name ON $table_str ($cols_list)"
    Repo.execute(sql)
    println("   -> Created index $index_name on $table_str")
end


# --- Legacy Helpers (for Backward Compatibility) ---

function create_table(name::String, columns::Vector{String})
    cols_sql = join(columns, ", ")
    sql = "CREATE TABLE IF NOT EXISTS $name ($cols_sql)"
    Repo.execute(sql)
    println("   -> Created table $name (legacy)")
end

function drop_table(name::Union{String, Symbol})
    n = string(name)
    Repo.execute("DROP TABLE IF EXISTS $n")
    println("   -> Dropped table $n")
end

function add_column(table::Union{String, Symbol}, col_def::String)
    t = string(table)
    Repo.execute("ALTER TABLE $t ADD COLUMN $col_def")
    println("   -> Added column to $t: $col_def")
end

function execute(sql::String)
    Repo.execute(sql)
end

# --- Internal Helpers ---

function _run_step(m::Module, step::Symbol)
    if isdefined(m, step)
        f = getproperty(m, step)
        f()
        return true
    end
    return false
end

# --- Core Migration Logic ---

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
    versions = Set{String}()
    rows = Repo.query("SELECT version FROM $MIGRATIONS_TABLE ORDER BY version ASC")
    for r in rows
        push!(versions, r.version)
    end
    return versions
end

function migrate(migrations_dir::String="db/migrations")
    migrations_dir = abspath(migrations_dir)
    if !isdir(migrations_dir)
        mkpath(migrations_dir)
        println("Created migrations directory: $migrations_dir")
        return
    end

    applied = get_applied_versions()
    files = filter(f -> endswith(f, ".jl"), readdir(migrations_dir))
    sort!(files)
    
    pending_count = 0
    
    for file in files
        version = split(file, "_")[1]
        if version in applied; continue; end
        
        println("== Migrating: $file ==")
        full_path = joinpath(migrations_dir, file)
        
        try
            m = Module()
            Core.eval(m, :(using Suindara.MigrationModule))
            Base.include(m, full_path)
            
            success = Base.invokelatest(_run_step, m, :up)
            
            if success
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
