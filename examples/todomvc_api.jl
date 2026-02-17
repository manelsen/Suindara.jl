module TodoMVC
    using Suindara
    using Suindara.MigrationModule
    using Suindara.ResourceModule
    using Suindara.Repo
    using Suindara.AuthModule
    using Suindara.OpenAPIModule
    using Suindara.SocketModule
    using Suindara.ChannelModule
    using Suindara.TemplateModule
    using Suindara.SessionModule
    using Suindara.CSRFModule
    using HTTP
    using JSON3
    using Dates

    # --- 1. CONFIGURATION ---
    const DB_PATH = "todomvc.db"
    const PORT = 8080

    function setup_db()
        Repo.connect(DB_PATH)
        
        # Determine if we need to migrate
        # In a real app, use the migration files. Here we force a schema for the example.
        Repo.execute("CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            completed BOOLEAN DEFAULT 0
        )")
        
        Repo.execute("CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT NOT NULL UNIQUE,
            token TEXT
        )")
        
        # Seed
        Repo.execute("INSERT OR IGNORE INTO users (username, token) VALUES ('admin', 'secret_token')")
    end

    # --- 2. MODELS ---
    struct Todo
        id::Int
        title::String
        completed::Bool
    end

    ResourceModule.schema(::Type{Todo}) = [:title, :completed]
    ResourceModule.table_name(::Type{Todo}) = "todos"

    # --- 3. CONTROLLERS ---
    module PageController
        using Suindara
        using Suindara.TemplateModule
        
        function index(conn::Conn)
            # Render a simple HTML Interface
            html = """
            <!DOCTYPE html>
            <html>
            <head><title>Suindara TodoMVC</title></head>
            <body>
                <h1>Todo List</h1>
                <ul id="list"></ul>
                <script>
                    // Connect to WebSocket
                    const ws = new WebSocket("ws://localhost:8080/ws");
                    ws.onmessage = (event) => {
                        const data = JSON.parse(event.data);
                        if (data.event === "new_todo") {
                            const li = document.createElement("li");
                            li.innerText = data.payload.title;
                            document.getElementById("list").appendChild(li);
                        }
                    };
                </script>
            </body>
            </html>
            """
            return plug_render_html(conn, html)
        end
    end

    # --- 4. CHANNELS (Real-time) ---
    module TodoChannel
        using Suindara.ChannelModule
        using Suindara.SocketModule

        function join(socket, topic, payload)
            if topic == "todos:updates"
                return :ok
            else
                return :error, "Unknown topic"
            end
        end

        function handle_in(event, payload, socket)
            return :noreply
        end
    end

    # --- 5. AUTH ---
    function verify_token(token::String)
        # Simple check against DB
        users = Repo.query("SELECT * FROM users WHERE token = ?", [token])
        return !isempty(users)
    end

    const auth_plug = AuthModule.make_bearer_plug(verify_token)

    # --- 6. ROUTER ---
    
    # Helper for the DSL if strict plug() usage is intended
    plug(f) = f

    @router ApiRouter begin
        # 1. API Pipeline
        pipeline(:api) do
            plug(Suindara.plug_json_parser)
            plug(Suindara.plug_cors)
        end

        # 2. Browser Pipeline
        pipeline(:browser) do
            plug(SessionModule.make_session_plug(SessionModule.MemorySessionStore()))
        end

        # 3. Protected Pipeline
        pipeline(:protected) do
            plug(auth_plug)
        end

        # WebSocket Endpoint
        socket("/ws", SocketHandler)

        # HTML Routes
        scope("/") do
            pipe_through(:browser)
            get("/", PageController.index)
        end

        # Public API
        scope("/api") do
            pipe_through(:api)
            
            # Auto-CRUD
            resources("/todos", ResourceController, Todo)
            
            # Swagger
            get("/swagger", conn -> render_json(conn, OpenAPIModule.generate_spec(ApiRouter)))
        end
        
        # Protected API
        scope("/admin") do
            pipe_through(:api)
            pipe_through(:protected)
            
            get("/stats", conn -> render_json(conn, Dict("status" => "secure")))
        end
    end

    # --- 7. MAIN ---
    function start()
        setup_db()
        println("🚀 TodoMVC running on http://localhost:$PORT")
        
        handler = Suindara.make_handler(ApiRouter)
        
        HTTP.serve(handler, "127.0.0.1", PORT)
    end
end
