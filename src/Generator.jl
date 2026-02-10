"""
    module GeneratorModule

Provides the CLI tooling for scaffolding new Suindara applications.
"""
module GeneratorModule

using Dates

export generate_project, generate_migration

"""
    generate_migration(name::String)

Creates a new migration file in `db/migrations/` with the current timestamp.
"""
function generate_migration(name::String)
    # Ensure directory exists
    mig_dir = "db/migrations"
    if !isdir(mig_dir)
        mkpath(mig_dir)
        println("Created directory $mig_dir")
    end

    # Format: YYYYMMDDHHMMSS_name.jl
    timestamp = Dates.format(now(), "yyyymmddHHMMSS")
    filename = "$(timestamp)_$(name).jl"
    path = joinpath(mig_dir, filename)

    content = """
# Migration: $name
# Created: $(now())
using Suindara.MigrationModule

function up()
    # create_table("table_name", ["id INTEGER PRIMARY KEY", "col TYPE"])
    # execute("CREATE TABLE ...")
end

function down()
    # drop_table("table_name")
end
"""
    write(path, content)
    println("Created migration: $path")
end

"""
    generate_project(name::String)

Scaffolds a new Suindara application structure.
...
"""
function generate_project(name::String)
    println("Creating Suindara project: $name...")
    
    # 1. Create directory structure
    mkpath("$name/src/controllers")
    mkpath("$name/db/migrations") # Added migrations folder
    mkpath("$name/test")
    
    # 2. Project.toml
    write("$name/Project.toml", """
[deps]
Suindara = "..." # Point to local path or registry
HTTP = "1.10.19"
JSON3 = "1.14.3"
SQLite = "1.6.0"
""")

    # 3. Main entry point (src/name.jl)
    write("$name/src/$name.jl", """
module $name
    using Suindara
    using SQLite
    
    include("router.jl")
    
    function start(port=8080)
        # Connect to DB
        db_path = joinpath(@__DIR__, "../db/dev.sqlite")
        Repo.connect(db_path)
        
        # Run migrations (basic)
        Repo.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)")
        
        println("Starting server on port \$port...")
        HTTP.serve(port) do req
            try
                match_and_dispatch(AppRouter, req)
            finally
                # Cleanup resources if necessary
            end
        end
    end
end
""")

    # 4. Router (src/router.jl)
    write("$name/src/router.jl", """
using Suindara
include("controllers/page_controller.jl")

@router AppRouter begin
    get("/", PageController.index)
    get("/users/:id", PageController.show)
end
""")

    # 5. Example Controller (src/controllers/page_controller.jl)
    write("$name/src/controllers/page_controller.jl", """
module PageController
    using Suindara
    
    function index(conn::Conn)
        return resp(conn, 200, "Welcome to Suindara on Julia!")
    end
    
    function show(conn::Conn)
        id = conn.params["id"]
        return resp(conn, 200, "Showing User \$id")
    end
end
""")

    # 6. Dockerfile (Production Ready)
    write("$name/Dockerfile", """
FROM julia:1.10

WORKDIR /app

# Copy Project Files
COPY Project.toml .
# COPY Manifest.toml . 

# Install Dependencies
# In a real setup, we'd precompile here
RUN julia --project=. -e 'using Pkg; Pkg.add(["HTTP", "JSON3", "SQLite"]); Pkg.instantiate();'

COPY src/ src/

# Entrypoint
CMD ["julia", "--project=.", "-e", "using $name; $name.start(8080)"]
""")

    println("Project $name created successfully!")
    println("Run 'cd $name' and start coding!")
end

end # module