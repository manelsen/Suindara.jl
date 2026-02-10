module DjangoChallenger
    using Suindara
    using Suindara.ResourceModule # Import explicit interface
    using SQLite

    # ==================================================================================
    # 1. O "MODEL" (Pure Structs)
    # ==================================================================================
    struct User
        id::Int
        name::String
        email::String
    end
    
    struct Product
        id::Int
        title::String
        price::Float64
    end

    # ==================================================================================
    # 2. A "CONFIGURAÇÃO" (Wiring the Resource)
    # Implementamos a interface do Suindara para conectar a struct ao DB.
    # ==================================================================================
    
    # User Config
    ResourceModule.schema(::Type{User}) = [:name, :email]
    ResourceModule.table_name(::Type{User}) = "users"

    # Product Config
    ResourceModule.schema(::Type{Product}) = [:title, :price]
    ResourceModule.table_name(::Type{Product}) = "products"

    # ==================================================================================
    # 3. O ROUTER
    # Usamos o `ResourceController` nativo do Suindara.
    # NENHUMA linha de lógica de controller foi escrita neste arquivo.
    # ==================================================================================
    @router ApiRouter begin
        # Users CRUD
        get("/users", conn -> ResourceController.index(conn, User))
        post("/users", conn -> ResourceController.create(conn, User))
        get("/users/:id", conn -> ResourceController.show(conn, User))
        put("/users/:id", conn -> ResourceController.update(conn, User))
        delete("/users/:id", conn -> ResourceController.delete(conn, User))

        # Products CRUD
        get("/products", conn -> ResourceController.index(conn, Product))
        post("/products", conn -> ResourceController.create(conn, Product))
        get("/products/:id", conn -> ResourceController.show(conn, Product))
    end

    function start(port=8084)
        # Setup DB
        Repo.connect(":memory:")
        Repo.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
        Repo.execute("CREATE TABLE products (id INTEGER PRIMARY KEY, title TEXT, price REAL)")

        println("Django Challenger (Built-in Edition) rodando na porta $port")
        println("CRUD Genérico pronto para uso!")
        
        HTTP.serve(port) do req
            conn = Conn(req)
            conn = plug_json_parser(conn)
            match_and_dispatch(ApiRouter, req)
        end
    end
end