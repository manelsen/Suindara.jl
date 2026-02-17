# Suindara Tutorial: Zero to Hero

Welcome to the **Suindara Framework** practical course. In this tutorial, we will build **SuinTask**, a complete SaaS task management system.

Each step introduces a new concept. Don't skip ahead!

---

## Part 1: Foundations

### Example 1: The Minimum Viable Product
Let's start a server that simply says "Hello".
**Concepts:** `Conn` (Connection) and `resp` (Response).

```julia
using Suindara
using HTTP

# a Controller is just a function
function hello(conn::Conn)
    return resp(conn, 200, "Hello, Suindara World!")
end

# Starting the server manually (without Router for now)
HTTP.serve(8080) do req
    conn = Conn(req)
    hello(conn)
end
```

### Example 2: The Router (Router DSL)
Organizing URLs and capturing parameters.
**Concepts:** `@router`, `:params`.

```julia
@router AppRouter begin
    get("/", conn -> resp(conn, 200, "Home"))
    get("/hello/:name", HelloController.greet) # /hello/micelio
end

module HelloController
    using Suindara
    function greet(conn::Conn)
        name = conn.params["name"]
        return resp(conn, 200, "Hello, $name!")
    end
end
```

### Example 3: Pipelines & Plugs
Transforming requests with composable functions.
**Concepts:** `pipeline`, `plug`, `pipe_through`.

```julia
@router AppRouter begin
    pipeline :api do
        plug(Suindara.plug_json_parser)
        plug(Suindara.plug_cors)
    end

    scope "/api" do
        pipe_through(:api)
        post("/tasks", TaskController.create)
    end
end
```

---

## Part 2: Data & Persistence

### Example 4: Database Setup (Repo)
Connecting to SQLite and executing raw SQL.
**Concepts:** `Repo.connect`, `Repo.execute`.

```julia
using Suindara.RepoModule

# Connect to SQLite
Repo.connect("suintask.db")

# Execute SQL
Repo.execute("CREATE TABLE IF NOT EXISTS logs (message TEXT)")
Repo.execute("INSERT INTO logs VALUES (?)", ["Server started"])
```

### Example 5: Migrations (Ecto Style)
Evolving your database schema professionally.
**Concepts:** `generate_migration`, `up/down`.

`db/migrations/20260210_create_tasks.jl`:
```julia
using Suindara.MigrationModule

function up()
    create_table("tasks", [
        "id INTEGER PRIMARY KEY",
        "title TEXT NOT NULL",
        "priority INTEGER DEFAULT 0",
        "done BOOLEAN DEFAULT 0"
    ])
end

function down()
    drop_table("tasks")
end
```

### Example 6: Changesets & Validation
Validating input data before it hits the database.
**Concepts:** `Changeset`, `cast`, `validate_required`.

```julia
# Payload: {"title": "Buy Bread", "priority": 1}
function create_task(conn::Conn)
    allowed = [:title, :priority]
    
    # 1. Cast and Filter
    ch = cast(conn.params, allowed)
    
    # 2. Validate
    ch = validate_required(ch, [:title])
    ch = validate_inclusion(ch, :priority, 1:5)
    
    if ch.valid
        # Save to DB (mock)
        return render_json(conn, ch.changes, status=201)
    else
        return render_json(conn, ch.errors, status=422)
    end
end
```

### Example 7: The Generic Resource (CRUD)
Creating a complete API without writing boilerplate code.
**Concepts:** `ResourceController`, `Interface`.

```julia
struct Task
    id::Int
    title::String
    priority::Int
    done::Bool
end

# Automagic Configuration
Suindara.ResourceModule.schema(::Type{Task}) = [:title, :priority, :done]
Suindara.ResourceModule.table_name(::Type{Task}) = "tasks"

@router ApiRouter begin
    # Automatically creates GET, POST, PUT, DELETE /tasks
    resources("/tasks", TaskController, Task)
end
```

---

## Part 3: Web Ecosystem (v1.0)

### Example 8: Authentication (Bearer Token)
Protecting routes with standardized auth plugs.
**Concepts:** `AuthModule`, `make_bearer_plug`.

```julia
# 1. Define verification logic
function verify_token(token::String)
    return token == "secret_token_123" # Replace with real DB lookup
end

# 2. Create the plug
const auth_plug = Suindara.AuthModule.make_bearer_plug(verify_token)

# 3. Use in Router
@router AppRouter begin
    pipeline :protected do
        plug(auth_plug)
    end

    scope "/admin" do
        pipe_through(:protected)
        get("/dashboard", AdminController.dashboard)
    end
end
```

### Example 9: Rate Limiting
Preventing abuse with Token Bucket algorithm.
**Concepts:** `RateLimiterModule`, `make_rate_limiter_plug`.

```julia
# Allow 10 requests per minute
const rate_limit = Suindara.RateLimiterModule.make_rate_limiter_plug(10, 60.0)

@router AppRouter begin
    pipeline :api do
        plug(rate_limit)
    end
    # ...
end
```

### Example 10: Auto-Generated Docs (OpenAPI)
Generating Swagger documentation from your router.
**Concepts:** `OpenAPIModule`, `generate_spec`.

```julia
# Generate spec
spec = Suindara.OpenAPIModule.generate_spec(AppRouter)

# Serve it
get("/swagger.json", conn -> render_json(conn, spec))
```

---

## Part 4: Real-Time (WebSockets)

### Example 11: Chat Channels
Building a real-time chat application.
**Concepts:** `socket`, `Channel`, `push`, `broadcast`.

**Router Setup:**
```julia
@router AppRouter begin
    socket "/ws", SocketHandler
end
```

**Channel Logic:**
```julia
module ChatChannel
    using Suindara.ChannelModule
    using Suindara.SocketModule

    # Handle joining a topic
    function join(socket, topic, payload)
        if topic == "room:lobby"
            return :ok
        else
            return :error, "Room not found"
        end
    end

    # Handle incoming events
    function handle_in("new_msg", payload, socket)
        # Broadcast to everyone in the topic
        broadcast(socket, "new_msg", payload)
        return :noreply
    end
end
```

---

## Part 5: Full-Stack Features

### Example 12: HTML Templates
Rendering dynamic HTML server-side.
**Concepts:** `TemplateModule`, `render_file`.

```julia
# views/home.html: <h1>Hello, {{name}}!</h1>

function home(conn::Conn)
    html = Suindara.TemplateModule.render_file("views/home.html", Dict("name" => "User"))
    return Suindara.TemplateModule.plug_render_html(conn, html)
end
```

### Example 13: Sessions & CSRF
Managing user state and security.
**Concepts:** `SessionModule`, `CSRFModule`.

```julia
const session_store = Suindara.SessionModule.MemorySessionStore()
const session_plug = Suindara.SessionModule.make_session_plug(session_store)
const csrf_plug = Suindara.CSRFModule.make_csrf_plug()

@router AppRouter begin
    pipeline :browser do
        plug(session_plug)
        plug(csrf_plug)
    end

    scope "/" do
        pipe_through(:browser)
        get("/", PageController.index)
        post("/login", AuthController.login)
    end
end
```

---

## Part 6: Advanced

### Example 14: Background Jobs
Sending emails without blocking the request.
**Concepts:** `Threads.@spawn`.

```julia
function register(conn::Conn)
    # ... create user ...
    
    # Fire and Forget
    Threads.@spawn begin
        sleep(5) # Simulate slow email sending
        println("Welcome email sent to $(conn.params["email"])")
    end
    
    return resp(conn, 201, "User Created")
end
```

### Example 15: Telemetry & Admin Dashboard
Monitoring system health.
**Concepts:** `TelemetryModule`.

```julia
# Instrumenting a critical section
Suindara.TelemetryModule.span("db_query") do
    Repo.query("SELECT * FROM heavy_table")
end

# Checking stats
stats = Suindara.TelemetryModule.get_metrics()
println("Average DB Latency: $(stats["db_query_avg_ms"]) ms")
```

---

**Congratulations!** You have built a modern, secure, and asynchronous backend.
Suindara doesn't hide complexity from you; it gives you the tools to master it.
