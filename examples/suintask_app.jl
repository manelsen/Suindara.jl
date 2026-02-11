# ==============================================================================
# SuinTask: A Complete Project Management SaaS built with Suindara
# Features: Auth, CRUD, Async Jobs, Dashboard, Migrations.
# ==============================================================================

module SuinTaskApp
    using Suindara
    using HTTP
    using Suindara.MigrationModule
    using Suindara.ResourceModule
    using Suindara.Repo
    using Base.Threads
    using Dates

    # --- 1. CONFIGURATION & DATABASE SETUP ---

    const DB_PATH = "suintask.db"
    const MIG_DIR = "suintask_migrations"

    function setup_db()
        Repo.connect(DB_PATH)
        mkpath(MIG_DIR)
        
        # Define Migrations explicitly (usually these are separate files)
        # We write them to disk to use the robust Migration System
        
        # 1. Users Table
        open(joinpath(MIG_DIR, "202601010000_create_users.jl"), "w") do io
            write(io, """
            using Suindara.MigrationModule
            function up()
                create_table("users", [
                    "id INTEGER PRIMARY KEY",
                    "email TEXT UNIQUE NOT NULL",
                    "role TEXT DEFAULT 'user'"
                ])
                # Seed Admin
                execute("INSERT INTO users (email, role) VALUES ('admin@suintask.com', 'admin')")
            end
            function down() drop_table("users") end
            """)
        end

        # 2. Tasks Table
        open(joinpath(MIG_DIR, "202601010001_create_tasks.jl"), "w") do io
            write(io, """
            using Suindara.MigrationModule
            function up()
                create_table("tasks", [
                    "id INTEGER PRIMARY KEY",
                    "title TEXT NOT NULL",
                    "status TEXT DEFAULT 'pending'",
                    "created_at DATETIME DEFAULT CURRENT_TIMESTAMP"
                ])
            end
            function down() drop_table("tasks") end
            """)
        end

        # Run Migrations
        println("[BOOT] Running Migrations...")
        migrate(MIG_DIR)
    end

    # --- 2. DATA MODELS (STRUCTS) ---

    struct Task
        id::Int
        title::String
        status::String
    end

    struct User
        id::Int
        email::String
        role::String
    end

    # Configure Generic Resource Controller
    ResourceModule.schema(::Type{Task}) = [:title, :status]
    ResourceModule.table_name(::Type{Task}) = "tasks"

    ResourceModule.schema(::Type{User}) = [:email, :role]
    ResourceModule.table_name(::Type{User}) = "users"

    # --- 3. BUSINESS LOGIC & CONTROLLERS ---

    module AuthController
        using Suindara
        
        function login(conn::Conn)
            # Fake Login: In real life, check password hash
            email = get(conn.params, "email", "")
            
            user = Repo.get_one("users", email; pk="email")
            
            if user !== nothing
                # Return a "Token" (just the ID for simplicity)
                return render_json(conn, Dict("token" => "user_$(user.id)", "role" => user.role))
            else
                return halt!(conn, 401, "Invalid Credentials")
            end
        end
    end

    module DashboardController
        using Suindara
        
        function stats(conn::Conn)
            # Aggregate queries
            u_count = first(Repo.query("SELECT count(*) as c FROM users")).c
            t_count = first(Repo.query("SELECT count(*) as c FROM tasks")).c
            
            # System stats
            return render_json(conn, Dict(
                "users" => u_count,
                "tasks" => t_count,
                "server_threads" => Threads.nthreads()
            ))
        end
    end

    # --- 4. MIDDLEWARE (PLUGS) ---

    function plug_auth_guard(conn::Conn)
        # Check Authorization Header
        token = HTTP.header(conn.request, "Authorization")
        
        if startswith(token, "user_")
            # Valid session
            user_id = parse(Int, replace(token, "user_" => ""))
            assign(conn, :current_user_id, user_id)
            return conn
        else
            return halt!(conn, 401, "Unauthorized: Missing Token")
        end
    end

    function plug_logger_async(conn::Conn)
        # Async Logging: Don't block the request!
        path = conn.request.target
        method = conn.request.method
        
        Threads.@spawn begin
            # Simulate slow IO (e.g., sending to Splunk/Datadog)
            sleep(0.1) 
            println("[LOG ASYNC] $method $path processed.")
        end
        return conn
    end

    # --- 5. ROUTER ---

    @router AppRouter begin
        # Public
        post("/login", AuthController.login)
        
        # Protected: Tasks CRUD (Generic)
        # We wrap the generic handler with our Auth Guard
        get("/tasks", conn -> begin
            c = plug_auth_guard(conn)
            !c.halted ? ResourceController.index(c, Task) : c
        end)
        
        post("/tasks", conn -> begin
            c = plug_auth_guard(conn)
            !c.halted ? ResourceController.create(c, Task) : c
        end)

        # Admin Dashboard
        get("/dashboard", DashboardController.stats)
    end

    # --- 6. SERVER ENTRYPOINT ---

    function start(port=8888)
        # 1. Setup DB
        setup_db()
        
        println("
🦅 SuinTask v1.0 is flying on port $(port)!")
        println("   - Admin User: admin@suintask.com")
        println("   - DB: $DB_PATH")
        println("   - Migrations: Applied.
")
        
        HTTP.serve(port) do req
            conn = Conn(req)
            conn = plug_json_parser(conn)
            
            # Global Plugs
            conn = plug_logger_async(conn)
            
            conn = match_and_dispatch(AppRouter, conn)
            
            return HTTP.Response(conn.status, conn.resp_headers, conn.resp_body)
        end
    end
end
