# 🍳 Suindara Cookbook (Complete Edition)

This practical guide provides recipes for solving common architecture, security, performance, and deployment problems in Suindara applications.

Inspired by the "Contexts" pattern from Phoenix Framework, this guide encourages a design where business logic is decoupled from the Web layer.

## Table of Contents

- [1. Architecture & Organization](#1-architecture--organization)
    - [The Context Pattern](#the-context-pattern)
    - [Recipe: Separating Accounts](#recipe-separating-accounts)
- [2. Real-Time & WebSockets](#2-real-time--websockets)
    - [Recipe: Setting up a Socket](#recipe-setting-up-a-socket)
    - [Recipe: Channel Event Handling](#recipe-channel-event-handling)
- [3. Security & Authentication](#3-security--authentication)
    - [Recipe: Password Hashing (Simple PBKDF2)](#recipe-password-hashing-simple-pbkdf2)
    - [Recipe: Token Authentication (Bearer)](#recipe-token-authentication-bearer)
    - [Recipe: CSRF Protection](#recipe-csrf-protection)
    - [Recipe: Rate Limiting](#recipe-rate-limiting)
- [4. API & Documentation](#4-api--documentation)
    - [Recipe: Auto-Generating OpenAPI Specs](#recipe-auto-generating-openapi-specs)
- [5. Observability & Telemetry](#5-observability--telemetry)
    - [Recipe: Instrumenting Pipelines](#recipe-instrumenting-pipelines)
- [6. Database Patterns](#6-database-patterns)
    - [Recipe: Seeds & Data Population](#recipe-seeds--data-population)
    - [Recipe: Efficient Pagination](#recipe-efficient-pagination)
    - [Recipe: Avoiding N+1 Queries (Manual Preloading)](#recipe-avoiding-n1-queries-manual-preloading)
- [7. Development Experience](#7-development-experience)
    - [Recipe: Hot Reloading with Revise](#recipe-hot-reloading-with-revise)
- [8. Deployment & Production](#8-deployment--production)
    - [Recipe: Configuration Management (ENV)](#recipe-configuration-management-env)
    - [Recipe: Optimized Dockerfile](#recipe-optimized-dockerfile)
- [9. Migrating from Django/Rails](#9-migrating-from-djangorails)
    - [Recipe: Composable Queries (Replacing Managers)](#recipe-composable-queries-replacing-managers)
    - [Recipe: Service Pipelines (Replacing Service Classes)](#recipe-service-pipelines-replacing-service-classes)

---

## 1. Architecture & Organization

### The Context Pattern

In Suindara (like Phoenix), we avoid placing business logic in Controllers. Controllers should only receive data, call a business function (Context), and return a response.

### Recipe: Separating Accounts

Create modules that group related functionality.

```julia
# src/contexts/Accounts.jl
module Accounts
    using ..Repo
    using ..ChangesetModule

    struct User
        id::Int
        email::String
        password_hash::String
    end

    # Schema for validation
    schema(::Type{User}) = [:email, :password]

    """
    Creates a user applying business rules (password hashing).
    """
    function register_user(attrs::Dict)
        # 1. Basic Validation
        ch = cast(attrs, schema(User))
        ch = validate_required(ch, [:email, :password])
        
        if !ch.valid return ch end

        # 2. Business Rule: Hash password
        pass = get(ch.changes, :password, "")
        ch.changes[:password_hash] = hash_password(pass)
        delete!(ch.changes, :password) # Never save raw password!

        # 3. Persistence
        try
            Repo.insert(ch, "users")
            return ch
        catch e
            # Handle uniqueness errors, etc.
            ch.valid = false
            ch.errors[:email] = "Email already exists"
            return ch
        end
    end

    function get_user_by_email(email)
        return Repo.get_one("users", email, pk="email")
    end

    # Private helper function
    function hash_password(password)
        # In production, use Argon2 or PBKDF2
        return bytes2hex(sha256(password * "SECRET_SALT")) 
    end
end
```

**In the Controller:**
```julia
module UserController
    using ..Accounts
    
    function create(conn)
        result = Accounts.register_user(conn.params)
        if result.valid
            render_json(conn, result.changes, status=201)
        else
            render_json(conn, result.errors, status=422)
        end
    end
end
```

---

## 2. Real-Time & WebSockets

Suindara provides native support for WebSockets via `SocketModule` and `ChannelModule`.

### Recipe: Setting up a Socket

Define a socket handler that maps to your router.

```julia
# src/socket_handler.jl
module AppSocket
    using Suindara.SocketModule
    using Suindara.ChannelModule

    # Define your channel registry
    const registry = ChannelRegistry()

    # Register channel handlers
    # Example: "room:*" matches "room:lobby", "room:123"
    register_handler!(registry, "room:*", :new_msg, (payload) -> begin
        println("Broadcasting message: ", payload)
        return Dict("status" => "sent", "body" => payload)
    end)

    # Main entry point for the router
    function handle(ws)
        SocketModule.handle_socket(ws, registry)
    end
end
```

**In your Router:**
```julia
@router ApiRouter begin
    socket("/ws", AppSocket.handle)
end
```

### Recipe: Channel Event Handling

Clients send JSON messages formatted like Phoenix Channels:
`{"topic": "room:1", "event": "new_msg", "payload": {"text": "Hello"}, "ref": "1"}`.

Suindara automatically dispatches these to your registered handlers.

---

## 3. Security & Authentication

### Recipe: Password Hashing (Simple PBKDF2)

Don't reinvent the wheel. Use libraries like `SHA` or `MbedTLS`, but here is a secure conceptual implementation.

```julia
using SHA

const GLOBAL_SALT = ENV["SECRET_KEY_BASE"] # Configure this in env!

function hash_pwd(password::String)
    # PBKDF2 Simulation (Many iterations to prevent brute-force)
    hash = password * GLOBAL_SALT
    for _ in 1:1000
        hash = bytes2hex(sha256(hash))
    end
    return hash
end

function verify_pwd(password::String, stored_hash::String)
    return hash_pwd(password) == stored_hash
end
```

### Recipe: Token Authentication (Bearer)

```julia
using Suindara.AuthModule

function verify_token(token::String)
    # Verify token against DB or validate JWT signature
    user = Accounts.get_user_by_token(token)
    return user !== nothing
end

# Create the plug
const auth_plug = AuthModule.make_bearer_plug(verify_token)

# Use in Router pipeline
pipeline(:protected) do
    plug(auth_plug)
end
```

### Recipe: CSRF Protection

Protect your non-GET requests from Cross-Site Request Forgery.

```julia
using Suindara.CSRFModule

pipeline(:browser) do
    plug(CSRFModule.make_csrf_plug())
end
```
*Note: This plug expects an `X-CSRF-Token` header or a `_csrf_token` parameter in form submissions.*

### Recipe: Rate Limiting

Protect your API from abuse using the Token Bucket algorithm.

```julia
using Suindara.RateLimiterModule

# Allow 60 requests per minute per IP
const rate_limit = RateLimiterModule.make_rate_limit_plug(
    max_requests=60, 
    window_seconds=60.0
)

pipeline(:api) do
    plug(rate_limit)
end
```

---

## 4. API & Documentation

### Recipe: Auto-Generating OpenAPI Specs

Suindara can inspect your `Router` and generate a standard OpenAPI 3.0 (Swagger) JSON specification.

```julia
using Suindara.OpenAPIModule

@router ApiRouter begin
    # ... your routes ...
    
    # Expose the spec at /swagger
    get("/swagger", conn -> begin
        spec = OpenAPIModule.generate_spec(
            ApiRouter,
            title="My Awesome API",
            version="1.0.0"
        )
        render_json(conn, spec)
    end)
end
```

---

## 5. Observability & Telemetry

### Recipe: Instrumenting Pipelines

Track latency and custom events using `TelemetryModule`.

```julia
using Suindara.TelemetryModule

# 1. Setup a store
const telemetry = TelemetryStore()

# 2. Attach a handler (e.g., logging)
attach!(telemetry, :request_finished, (data) -> begin
    println("Request took $(data[:latency])ms")
end)

# 3. Emit events in your Plugs or Contexts
function timing_plug(conn)
    latency = TelemetryModule.measure_latency() do
        # ... logic ...
    end
    emit(telemetry, :request_finished, Dict(:latency => latency))
    return conn
end
```

---

## 6. Database Patterns

### Recipe: Seeds & Data Population

Create a `priv/repo/seeds.jl` file to populate the initial database.

```julia
# priv/repo/seeds.jl
using Suindara
using Suindara.Repo

Repo.connect("dev.db")

function seed!()
    println("🌱 Seeding database...")
    
    Repo.execute("DELETE FROM users")
    
    Repo.execute("INSERT INTO users (email, role) VALUES (?, ?)", 
        ["admin@example.com", "admin"])
        
    println("✅ Done.")
end

seed!()
```

### Recipe: Efficient Pagination

Never return unlimited `SELECT *` on large tables.

```julia
function paginate(query::String, page::Int=1, per_page::Int=20, params=[])
    offset = (page - 1) * per_page
    limit_query = "$query LIMIT $per_page OFFSET $offset"
    
    return Repo.query(limit_query, params)
end
```

### Recipe: Avoiding N+1 Queries (Manual Preloading)

Suindara does not have a complex ORM, so perform association loading manually for performance.

**Wrong (N+1):**
```julia
tasks = Repo.query("SELECT * FROM tasks")
for task in tasks
    # Executes 1 query per task! DANGER!
    user = Repo.get_one("users", task.user_id) 
end
```

**Correct (Preload):**
```julia
tasks = Repo.query("SELECT * FROM tasks")
user_ids = unique([t.user_id for t in tasks])

# Fetch all related users at once
placeholders = join(["?" for _ in user_ids], ",")
users_query = Repo.query("SELECT * FROM users WHERE id IN ($placeholders)", user_ids)

# Map for fast access
users_map = Dict(u.id => u for u in users_query)

# Associate in memory
tasks_with_users = []
for task in tasks
    user = get(users_map, task.user_id, nothing)
    push!(tasks_with_users, merge(Dict(pairs(task)), Dict("user" => user)))
end
```

---

## 7. Development Experience

### Recipe: Hot Reloading with Revise

Accelerate your dev loop by automatically reloading changed code.

```julia
using Suindara.HotReloadModule

# In your main dev entrypoint:
if Suindara.env() == "dev"
    HotReloadModule.start_watching()
end
```
*Requires `Revise.jl` to be in your environment.*

---

## 8. Deployment & Production

### Recipe: Configuration Management (ENV)

Use `ENV` with default values. Create a `config/config.jl` file.

```julia
module Config
    function get_port()
        return parse(Int, get(ENV, "PORT", "8080"))
    end
    
    function get_secret_key()
        key = get(ENV, "SECRET_KEY_BASE", nothing)
        if key === nothing && get(ENV, "SUINDARA_ENV", "dev") == "prod"
            error("SECRET_KEY_BASE is required in production!")
        end
        return key
    end
end
```

### Recipe: Optimized Dockerfile

A Multi-stage Dockerfile to keep the image small.

```dockerfile
# Stage 1: Builder
FROM julia:1.10-alpine as builder
WORKDIR /app
RUN apk add --no-cache build-base
COPY Project.toml .
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
COPY . .

# Stage 2: Runner
FROM julia:1.10-alpine
WORKDIR /app
RUN addgroup -S suindara && adduser -S suindara -G suindara
COPY --from=builder /app /app
USER suindara
ENV JULIA_PROJECT=.
ENV PORT=8080
EXPOSE 8080
CMD ["julia", "bin/suindara"]
```

---

## 9. Migrating from Django/Rails

If you are coming from Django or Rails, you might miss certain abstractions. Here is how to translate those patterns to Suindara's functional style.

### Recipe: Composable Queries (Replacing Managers)

In Django, you would do `User.objects.active().premium()`. In Suindara, we compose functions that return `(sql, params)` tuples.

```julia
module UserQueries
    using Suindara.Repo

    base() = ("SELECT * FROM users WHERE 1=1", [])

    function active(q)
        sql, params = q
        return ("$sql AND active = ?", [params..., 1])
    end

    function premium(q)
        sql, params = q
        return ("$sql AND plan = ?", [params..., "premium"])
    end

    function all(q)
        sql, params = q
        return Repo.query(sql, params)
    end
end

# Usage with Pipe operator |>
# users = UserQueries.base() |> UserQueries.active |> UserQueries.premium |> UserQueries.all
```

### Recipe: Service Pipelines (Replacing Service Classes)

Instead of creating `UserService` classes with static methods, use the pipe operator to define clear data flows.

```julia
module UserOnboarding
    struct Context
        params::Dict
        user::Union{Nothing, Dict}
        email_sent::Bool
    end

    function run(params)
        ctx = Context(params, nothing, false)
        return ctx |> validate |> persist |> send_welcome_email
    end
    # ... implementation of steps ...
end
```

---

**Suindara Framework** - Built to be simple, fast, and explicit.
