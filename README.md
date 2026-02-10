# Suindara.jl 🦉🔥

**Suindara** is a high-performance web framework for the Julia language, inspired by the architecture and philosophy of the **Phoenix Framework (Elixir)**. 

Named after the Brazilian Barn Owl, Suindara is designed to be fast, silent, and precise, leveraging Julia's multiple dispatch and metaprogramming to provide a "batteries-included" experience for modern web development.

---

## 🚀 Key Features

- **Pipeline Architecture:** Every request is a `Conn` (Connection) struct flowing through a functional pipeline of "Plugs".
- **Phoenix-like Router:** A beautiful, declarative DSL for defining routes with dynamic parameters (`/users/:id`).
- **Changesets & Validation:** Decoupled data validation and casting inspired by Ecto.
- **Embedded Database:** Native support for SQLite with a `Repo` pattern for clean data access.
- **Production Ready:** Includes a built-in **Generator CLI**, Docker support, and automatic JSON parsing.
- **Extreme Performance:** Built on top of `HTTP.jl` and `JSON3.jl`, fully compiled by Julia's JIT.

---

## 🛠 Installation

```julia
using Pkg
Pkg.add(url="https://github.com/manelsen/Suindara.jl")
```

---

## 🏁 Quick Start

### 1. Create a new project
Use the Suindara CLI to scaffold your application:
```bash
./bin/suindara new my_app
```

### 2. Define a Controller
```julia
module UserController
    using Suindara
    
    function show(conn::Conn)
        id = conn.params[:id]
        return resp(conn, 200, "User ID: $id")
    end
end
```

### 3. Set up the Router
```julia
@router AppRouter begin
    get("/", PageController.index)
    get("/users/:id", UserController.show)
end
```

---

## 🧪 Running Tests

Suindara follows strict TDD principles. Run the full test suite with:
```bash
julia --project=. test/runtests.jl
```

---

## 🇧🇷 Por que Suindara?

A **Suindara** (*Tyto furcata*) é uma coruja conhecida por seu voo silencioso e sua audição excepcional. Assim como a coruja, este framework foi criado para ser eficiente e robusto, permitindo que desenvolvedores Julia capturem a produtividade do ecossistema Elixir/Phoenix sem abrir mão da performance computacional pura do Julia.

---

## 📄 License
MIT License. Created with ❤️ by the Julia Community.
