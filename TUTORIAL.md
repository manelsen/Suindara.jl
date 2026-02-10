# Tutorial Suindara: Do Zero ao Admin em 1 Dia

Bem-vindo ao curso prático do **Suindara Framework**. Hoje vamos construir o **SuinTask**, um sistema de gestão de tarefas (SaaS) completo.

Cada passo introduz um conceito novo. Não pule etapas!

---

## Parte 1: Fundamentos

### Exemplo 1: O Mínimo Produto Viável
Vamos subir um servidor que apenas diz "Olá".
**Conceito:** `Conn` (Conexão) e `resp` (Resposta).

```julia
using Suindara
using HTTP

# Um Controller é apenas uma função
function hello(conn::Conn)
    return resp(conn, 200, "Olá, Mundo Suindara!")
end

# Subindo o servidor na mão (sem Router ainda)
HTTP.serve(8080) do req
    conn = Conn(req)
    hello(conn)
end
```

### Exemplo 2: O Roteador (Router DSL)
Organizando URLs e capturando parâmetros.
**Conceito:** `@router`, `:params`.

```julia
@router AppRouter begin
    get("/", conn -> resp(conn, 200, "Home"))
    get("/hello/:name", HelloController.greet) # /hello/micelio
end

module HelloController
    using Suindara
    function greet(conn::Conn)
        name = conn.params[:name]
        return resp(conn, 200, "Olá, $name!")
    end
end
```

### Exemplo 3: JSON e Changesets
Validando entrada de dados.
**Conceito:** `plug_json_parser`, `Changeset`, `cast`.

```julia
# O Payload: {"title": "Comprar Pão", "priority": 1}
function create_task(conn::Conn)
    # 1. Definir o que é permitido
    allowed = [:title, :priority]
    
    # 2. Filtrar e Validar
    ch = cast(conn.params, allowed)
    ch = validate_required(ch, [:title])
    
    if ch.valid
        return render_json(conn, ch.changes, status=201)
    else
        return render_json(conn, ch.errors, status=422)
    end
end
```

---

## Parte 2: Persistência e Dados

### Exemplo 4: Banco de Dados (Raw SQL)
Conectando e inserindo sem abstrações.
**Conceito:** `Repo.connect`, `Repo.execute`.

```julia
Repo.connect("suintask.db")
Repo.execute("CREATE TABLE IF NOT EXISTS logs (message TEXT)")
Repo.execute("INSERT INTO logs VALUES (?)", ["Servidor iniciou"])
```

### Exemplo 5: Migrations (Ecto Style)
Evoluindo o banco de forma profissional.
**Conceito:** `generate_migration`, `up/down`.

`db/migrations/20260210_create_tasks.jl`:
```julia
using Suindara.MigrationModule
function up()
    create_table("tasks", [
        "id INTEGER PRIMARY KEY",
        "title TEXT NOT NULL",
        "done BOOLEAN DEFAULT 0"
    ])
end
```

### Exemplo 6: O Recurso Genérico (CRUD)
Criando uma API completa sem escrever código.
**Conceito:** `ResourceController`, `Interface`.

```julia
struct Task
    id::Int
    title::String
    done::Bool
end

# Configuração Mágica
Suindara.ResourceModule.schema(::Type{Task}) = [:title, :done]
Suindara.ResourceModule.table_name(::Type{Task}) = "tasks"

@router ApiRouter begin
    # Cria GET, POST, PUT, DELETE /tasks automaticamente
    post("/tasks", conn -> ResourceController.create(conn, Task))
    get("/tasks", conn -> ResourceController.index(conn, Task))
end
```

---

## Parte 3: Segurança e Autenticação

### Exemplo 7: Modelando Usuários (Auth)
Preparando o terreno para login. Hash de senha (simulado para brevidade).

```julia
struct User
    id::Int
    email::String
    password_hash::String
end

function login(conn::Conn)
    email = conn.params[:email]
    password = conn.params[:password]
    
    # Busca no banco
    user = Repo.get_one("users", email; pk="email")
    
    if user !== nothing && user.password_hash == fake_hash(password)
        token = "sessao_$(user.id)"
        return render_json(conn, Dict("token" => token))
    else
        return halt!(conn, 401, "Credenciais Inválidas")
    end
end
```

### Exemplo 8: Plugs de Proteção (Middleware)
Interceptando requisições para checar tokens.
**Conceito:** `conn.assigns`, `halt!`.

```julia
function plug_require_auth(conn::Conn)
    token = HTTP.header(conn.request, "Authorization")
    
    if token == "segredo" # Simplificado
        assign(conn, :current_user_id, 1) # Injeta usuário na sessão
        return conn
    else
        return halt!(conn, 401, "Token Ausente")
    end
end

# No Router:
get("/secrets", conn -> begin
    conn = plug_require_auth(conn) # Executa o plug
    if !conn.halted
        SecretController.show(conn)
    else
        conn # Retorna o erro 401 definido no plug
    end
end)
```

---

## Parte 4: Avançado

### Exemplo 9: Jobs Assíncronos (Background)
Enviando email de boas-vindas sem travar a API.
**Conceito:** `Threads.@spawn`.

```julia
function register(conn::Conn)
    # ... cria usuário ...
    
    # Fire and Forget
    Threads.@spawn begin
        sleep(5) # Simula envio de email demorado
        println("Email enviado para $(conn.params[:email])")
    end
    
    return resp(conn, 201, "Criado")
end
```

### Exemplo 10: O Admin Dashboard
Agregando dados e monitorando o sistema.

```julia
module AdminController
    using Suindara
    
    function stats(conn::Conn)
        # Consultas agregadas
        total_users = first(Repo.query("SELECT count(*) as c FROM users")).c
        total_tasks = first(Repo.query("SELECT count(*) as c FROM tasks")).c
        
        # Estado do Sistema
        mem_usage = Sys.summarysize(Suindara) / 1024 / 1024 # MB
        threads = Threads.nthreads()
        
        return render_json(conn, Dict(
            "business" => Dict(
                "users" => total_users,
                "tasks" => total_tasks
            ),
            "system" => Dict(
                "memory_mb" => mem_usage,
                "threads" => threads,
                "uptime" => time() - START_TIME
            )
        ))
    end
end
```

---

**Parabéns!** Você construiu um backend moderno, seguro e assíncrono.
O Suindara não esconde a complexidade de você, ele te dá ferramentas para dominá-la.
