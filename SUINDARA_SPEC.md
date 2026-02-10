# Suindara.jl: Engineering & Architectural Specification

## 1. Vision & Philosophy
**Suindara.jl** is a web framework for Julia inspired by the **Phoenix Framework (Elixir)**. It prioritizes explicit data flow, functional transformation, and high performance by leveraging Julia's **Multiple Dispatch** and **Metaprogramming** capabilities.

### Core Principles:
- **Explicit over Implicit:** Avoid global state and "magic" behavior.
- **The Connection as a Pipeline:** A request is a data structure (`Conn`) that flows through a series of pure (or side-effecting) functions (the "Pipeline").
- **Multiple Dispatch as Pattern Matching:** Use Julia's type system to handle routing and data transformation.
- **Performance First:** Minimize overhead by using Julia's JIT and task-based concurrency.

---

## 2. Engineering Requirements

### 2.1 Technical Stack
- **Language:** Julia 1.10+ (LTS).
- **Base Server:** `HTTP.jl` for low-level protocol handling.
- **Serialization:** `JSON3.jl` for high-performance JSON.
- **Concurrency:** Julia `Tasks` (Green threads).

### 2.2 Functional Requirements
- **Pipeline Architecture:** A composable system to transform the request state.
- **Robust Routing:** A DSL for defining routes that compiles to efficient dispatch logic.
- **Changesets & Validation:** Decoupled data validation inspired by Elixir's Ecto.
- **Controller/Action Pattern:** Clear separation of concerns for handling business logic.

---

## 3. Architectural Design

### 3.1 The `Conn` Object
The `Conn` (Connection) struct is the heart of Suindara. It contains:
- `request`: The raw HTTP request.
- `params`: Parsed query and body parameters.
- `assigns`: A key-value store for sharing data between pipeline steps.
- `status`: HTTP response status.
- `resp_body`: The response content.
- `halted`: A boolean to stop the pipeline early (e.g., failed auth).

### 3.2 The Pipeline (Plugs)
Functions that take a `Conn` and return a `Conn`.
```julia
function authenticate(conn::Conn)::Conn
    if has_token(conn)
        return assign(conn, :user, user)
    else
        return halt!(conn, 401)
    end
end
```

### 3.3 Routing DSL
Using macros to define routes that map to specific controller functions.
```julia
@router MyRouter begin
    pipeline :api do
        plug(JSONParser)
        plug(VerifyAuth)
    end

    scope "/api" do
        pipe_through(:api)
        get("/users", UserController, :index)
    end
end
```

### 3.4 Multiple Dispatch Integration
Instead of complex "before_action" hooks, Suindara uses Multiple Dispatch on the Controller type or Action symbol to provide extensibility.

---

## 4. Implementation Roadmap

### Phase 1: The Core (MVP)
- [ ] Define the `Conn` struct.
- [ ] Implement the `plug` mechanism (Pipeline execution).
- [ ] Basic Router macro that maps paths to functions.
- [ ] Integration with `HTTP.jl`.

### Phase 2: Data & Validation (Ecto-like)
- [ ] Implementation of `Changeset` for data validation.
- [ ] Schema macros to map Julia structs to database/input expectations.

### Phase 3: Web Ecosystem
- [ ] JSON and Form Body parsers.
- [ ] Error handling and Debug pages.
- [ ] Performance benchmarking vs. Genie.jl.

### Phase 4: Real-time (Optional/Future)
- [ ] Julia-native Channels (WebSockets).

---

## 5. Development Guidelines
1. **Purity:** Keep pipeline steps as side-effect-free as possible regarding the global state.
2. **Type Stability:** Ensure `Conn` and its fields are type-stable for maximum JIT optimization.
3. **Documentation:** Every public-facing macro and function must have a docstring.
4. **Testing:** Each phase must include unit tests for the core logic.

---

## 6. Project Structure
```text
Suindara/
├── src/
│   ├── Suindara.jl        # Main Module
│   ├── Conn.jl            # Connection logic
│   ├── Router.jl          # Macro-based Routing
│   ├── Controller.jl      # Base Controller logic
│   ├── Pipeline.jl        # Plug execution engine
│   └── Changeset.jl       # Validation logic
├── test/                  # Test suite
└── examples/              # Usage demos
```
