# 🍳 Suindara Cookbook (Edição Completa)

Este guia prático fornece receitas para resolver problemas comuns de arquitetura, segurança, performance e deploy em aplicações Suindara. 

Inspirado nos "Contexts" do Phoenix Framework, este guia encoraja um design onde a lógica de negócio é desacoplada da camada Web.

## Índice

- [🍳 Suindara Cookbook (Edição Completa)](#-suindara-cookbook-edição-completa)
  - [Índice](#índice)
  - [1. Arquitetura e Organização](#1-arquitetura-e-organização)
    - [O Padrão de Contextos (Contexts)](#o-padrão-de-contextos-contexts)
    - [Receita: Separando Contas (Accounts)](#receita-separando-contas-accounts)
  - [2. Segurança e Autenticação](#2-segurança-e-autenticação)
    - [Receita: Hash de Senhas (PBKDF2 Simples)](#receita-hash-de-senhas-pbkdf2-simples)
    - [Receita: Autenticação via Token (Bearer)](#receita-autenticação-via-token-bearer)
    - [Receita: Protegendo Recursos (Plugs de Autorização)](#receita-protegendo-recursos-plugs-de-autorização)
  - [3. Banco de Dados Avançado](#3-banco-de-dados-avançado)
    - [Receita: Seeds e População de Dados](#receita-seeds-e-população-de-dados)
    - [Receita: Paginação Eficiente](#receita-paginação-eficiente)
    - [Receita: Evitando N+1 (Preloading Manual)](#receita-evitando-n1-preloading-manual)
  - [4. Middleware e Plugs](#4-middleware-e-plugs)
    - [Receita: CORS (Cross-Origin Resource Sharing)](#receita-cors-cross-origin-resource-sharing)
    - [Receita: Request ID e Rastreabilidade](#receita-request-id-e-rastreabilidade)
  - [5. Testes e Qualidade](#5-testes-e-qualidade)
    - [Receita: Factories para Testes](#receita-factories-para-testes)
    - [Receita: Testando Upload de Arquivos](#receita-testando-upload-de-arquivos)
  - [6. Deploy e Produção](#6-deploy-e-produção)
    - [Receita: Gerenciamento de Configuração (ENV)](#receita-gerenciamento-de-configuração-env)
    - [Receita: Dockerfile Otimizado](#receita-dockerfile-otimizado)
  - [7. Migrando do Django (Receitas Avançadas)](#7-migrando-do-django-receitas-avançadas)
    - [Receita: Queries Composáveis (Substituindo Managers)](#receita-queries-composáveis-substituindo-managers)
    - [Receita: Pipelines de Serviço (Substituindo Service Classes)](#receita-pipelines-de-serviço-substituindo-service-classes)
    - [Receita: Hooks Explícitos (Substituindo Signals)](#receita-hooks-explícitos-substituindo-signals)

---

## 1. Arquitetura e Organização

### O Padrão de Contextos (Contexts)

No Phoenix, evitamos colocar lógica de negócio nos Controllers. Controllers devem apenas receber dados, chamar uma função de negócio e devolver uma resposta.

### Receita: Separando Contas (Accounts)

Crie módulos que agrupam funcionalidades relacionadas.

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

    # Schema para validação
    schema(::Type{User}) = [:email, :password]

    """
    Cria um usuário aplicando regras de negócio (hashing de senha).
    """
    function register_user(attrs::Dict)
        # 1. Validação básica
        ch = cast(attrs, schema(User))
        ch = validate_required(ch, [:email, :password])
        
        if !ch.valid return ch end

        # 2. Regra de Negócio: Hash da senha
        pass = get(ch.changes, :password, "")
        ch.changes[:password_hash] = hash_password(pass)
        delete!(ch.changes, :password) # Nunca salvar a senha crua!

        # 3. Persistência
        try
            Repo.insert(ch, "users")
            return ch
        catch e
            # Tratamento de erro de unicidade, etc.
            ch.valid = false
            ch.errors[:email] = "Email já existe"
            return ch
        end
    end

    function get_user_by_email(email)
        return Repo.get_one("users", email, pk="email")
    end

    # Função auxiliar privada
    function hash_password(password)
        # Em produção, use Argon2 ou PBKDF2
        return bytes2hex(sha256(password * "SALT_SECRETO")) 
    end
end
```

**No Controller:**
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

## 2. Segurança e Autenticação

### Receita: Hash de Senhas (PBKDF2 Simples)

Não reinvente a roda. Use bibliotecas como `SHA` ou `MbedTLS` se disponível, mas aqui está uma implementação conceitual segura.

```julia
using SHA

const SALT_GLOBAL = ENV["SECRET_KEY_BASE"] # Configure isso no env!

function hash_pwd(password::String)
    # Simulação de PBKDF2 (Muitas iterações para evitar brute-force)
    hash = password * SALT_GLOBAL
    for _ in 1:1000
        hash = bytes2hex(sha256(hash))
    end
    return hash
end

function verify_pwd(password::String, stored_hash::String)
    return hash_pwd(password) == stored_hash
end
```

### Receita: Autenticação via Token (Bearer)

```julia
function login(conn)
    email = conn.params[:email]
    pass = conn.params[:password]
    
    user = Accounts.get_user_by_email(email)
    
    if user !== nothing && verify_pwd(pass, user.password_hash)
        # Gere um token real (JWT) em produção. 
        # Aqui usamos um token opaco simples.
        token = "suin_$(base64encode(user.id))_$(time())"
        
        # Salvar token em tabela de sessões ou Redis seria ideal
        return render_json(conn, Dict("token" => token))
    else
        halt!(conn, 401, "Credenciais Inválidas")
    end
end
```

### Receita: Protegendo Recursos (Plugs de Autorização)

```julia
function plug_ensure_admin(conn::Conn)
    user_id = get(conn.assigns, :current_user_id, nothing)
    
    if user_id === nothing
        return halt!(conn, 401, "Não autenticado")
    end
    
    user = Repo.get_one("users", user_id)
    if user.role != "admin"
        return halt!(conn, 403, "Proibido: Requer privilégios de Admin")
    end
    
    return conn
end
```

---

## 3. Banco de Dados Avançado

### Receita: Seeds e População de Dados

Crie um arquivo `priv/repo/seeds.jl` para popular o banco inicial.

```julia
# priv/repo/seeds.jl
using Suindara
using Suindara.Repo

Repo.connect("dev.db")

function seed!()
    println("🌱 Semeando banco de dados...")
    
    # Limpar dados antigos
    Repo.execute("DELETE FROM users")
    
    # Inserir Admin
    Repo.execute("INSERT INTO users (email, role) VALUES (?, ?)", 
        ["admin@example.com", "admin"])
        
    # Inserir Dados Dummy
    for i in 1:10
        Repo.execute("INSERT INTO tasks (title, status) VALUES (?, ?)", 
            ["Tarefa $i", "pending"])
    end
    
    println("✅ Concluído.")
end

seed!()
```

### Receita: Paginação Eficiente

Nunca retorne `SELECT *` sem limite em tabelas grandes.

```julia
function paginate(query::String, page::Int=1, per_page::Int=20, params=[])
    offset = (page - 1) * per_page
    limit_query = "$query LIMIT $per_page OFFSET $offset"
    
    return Repo.query(limit_query, params)
end

# Uso
page = parse(Int, get(conn.params, :page, "1"))
users = paginate("SELECT * FROM users", page)
```

### Receita: Evitando N+1 (Preloading Manual)

Suindara não tem ORM complexo, então faça o carregamento de associações manualmente para performance.

**Errado (N+1):**
```julia
tasks = Repo.query("SELECT * FROM tasks")
for task in tasks
    # Executa 1 query por tarefa! PERIGO!
    user = Repo.get_one("users", task.user_id) 
end
```

**Correto (Preload):**
```julia
tasks = Repo.query("SELECT * FROM tasks")
user_ids = unique([t.user_id for t in tasks])

# Busca todos os usuários relacionados de uma vez
placeholders = join(["?" for _ in user_ids], ",")
users_query = Repo.query("SELECT * FROM users WHERE id IN ($placeholders)", user_ids)

# Cria um mapa para acesso rápido
users_map = Dict(u.id => u for u in users_query)

# Associa em memória
tasks_with_users = []
for task in tasks
    user = get(users_map, task.user_id, nothing)
    push!(tasks_with_users, merge(Dict(pairs(task)), Dict("user" => user)))
end
```

---

## 4. Middleware e Plugs

### Receita: CORS (Cross-Origin Resource Sharing)

Necessário se seu frontend (React/Vue) estiver em outro domínio/porta.

```julia
function plug_cors(conn::Conn)
    # Permite qualquer origem (Cuidado em produção!)
    push!(conn.resp_headers, "Access-Control-Allow-Origin" => "*")
    push!(conn.resp_headers, "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS")
    push!(conn.resp_headers, "Access-Control-Allow-Headers" => "Content-Type, Authorization")
    
    # Responder imediatamente a requisições OPTIONS (Pre-flight)
    if conn.request.method == "OPTIONS"
        return halt!(conn, 204, "")
    end
    
    return conn
end
```

### Receita: Request ID e Rastreabilidade

Adicione um ID único para rastrear logs em sistemas distribuídos.

```julia
using UUIDs

function plug_request_id(conn::Conn)
    req_id = get(Dict(conn.request.headers), "x-request-id", string(uuid4()))
    
    # Devolve o ID no header da resposta para debug do cliente
    push!(conn.resp_headers, "X-Request-ID" => req_id)
    
    # Coloca no assigns para uso no Logger
    assign(conn, :request_id, req_id)
    
    return conn
end
```

---

## 5. Testes e Qualidade

### Receita: Factories para Testes

Crie dados de teste de forma declarativa (inspirado no ExMachina).

```julia
module Factory
    using Suindara.Repo
    
    function user_factory(attrs=Dict())
        defaults = Dict(
            "email" => "user_$(rand(1000:9999))@test.com",
            "role" => "user"
        )
        merge!(defaults, attrs)
        
        Repo.execute("INSERT INTO users (email, role) VALUES (?, ?)", 
            [defaults["email"], defaults["role"]])
            
        return Repo.get_one("users", defaults["email"], pk="email")
    end
end
```

### Receita: Testando Upload de Arquivos

Simulando um multipart upload.

```julia
@testset "Upload de Avatar" begin
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    body = """
    --$boundary
    Content-Disposition: form-data; name="avatar"; filename="me.png"
    Content-Type: image/png

    (dados binários simulados)
    --$boundary--
    """
    
    req = HTTP.Request("POST", "/upload", 
        ["Content-Type" => "multipart/form-data; boundary=$boundary"], 
        body)
        
    conn = Conn(req)
    # ... dispatch ...
    @test conn.status == 200
end
```

---

## 6. Deploy e Produção

### Receita: Gerenciamento de Configuração (ENV)

Use `ENV` com valores padrão. Crie um arquivo `config/config.jl`.

```julia
module Config

    function get_port()
        return parse(Int, get(ENV, "PORT", "8080"))
    end

    function get_db_path()
        return get(ENV, "DATABASE_URL", "suindara_prod.db")
    end
    
    function get_secret_key()
        key = get(ENV, "SECRET_KEY_BASE", nothing)
        if key === nothing && get(ENV, "SUINDARA_ENV", "dev") == "prod"
            error("SECRET_KEY_BASE é obrigatória em produção!")
        end
        return key
    end

end
```

### Receita: Dockerfile Otimizado

Um Dockerfile Multi-stage para manter a imagem pequena.

```dockerfile
# Estágio 1: Builder
FROM julia:1.10-alpine as builder

WORKDIR /app

# Instalar dependências do SO necessárias para compilar pacotes (se houver)
RUN apk add --no-cache build-base

# Copiar manifesto do projeto
COPY Project.toml .

# Instalar dependências e pré-compilar
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# Copiar código fonte
COPY . .

# (Opcional) Compilar um sysimage customizado com PackageCompiler.jl para startup rápido
# RUN julia --project=. scripts/create_sysimage.jl

# Estágio 2: Runner
FROM julia:1.10-alpine

WORKDIR /app

# Criar usuário não-root por segurança
RUN addgroup -S suindara && adduser -S suindara -G suindara

COPY --from=builder /app /app
# Se criou sysimage, copie também

USER suindara

ENV JULIA_PROJECT=.
ENV PORT=8080

EXPOSE 8080

CMD ["julia", "bin/suindara"]

```



---



## 7. Migrando do Django (Receitas Avançadas)



Se você vem do Django ou Rails, pode sentir falta de certas abstrações. Aqui está como traduzir esses padrões para o estilo funcional do Suindara.



### Receita: Queries Composáveis (Substituindo Managers)



No Django, você faria `User.objects.active().premium()`. No Suindara, compomos funções que retornam tuplas de `(sql, params)`.



```julia

module UserQueries

    using Suindara.Repo



    # Base Query

    base() = ("SELECT * FROM users WHERE 1=1", [])



    # Modificadores (Filtros)

    function active(q)

        sql, params = q

        return ("$sql AND active = ?", [params..., 1])

    end



    function premium(q)

        sql, params = q

        return ("$sql AND plan = ?", [params..., "premium"])

    end



    # Executor

    function all(q)

        sql, params = q

        return Repo.query(sql, params)

    end

end



# Uso com Pipe operator |>

# users = UserQueries.base() |> UserQueries.active |> UserQueries.premium |> UserQueries.all

```



### Receita: Pipelines de Serviço (Substituindo Service Classes)



Em vez de criar classes `UserService` com métodos estáticos, use o operador pipe para definir fluxos de dados claros.



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



    function validate(ctx)

        # Se já falhou, passa reto

        if ctx === nothing return nothing end

        # ... lógica de validação ...

        return ctx

    end



    function persist(ctx)

        if ctx === nothing return nothing end

        # ... Repo.insert ...

        # Retorna novo contexto com usuário salvo

        return Context(ctx.params, saved_user, false)

    end

    

    # ...

end

```



### Receita: Hooks Explícitos (Substituindo Signals)



Signals do Django (`post_save`) são famosos por "mágica" difícil de rastrear. Prefira injeção de dependência ou wrappers explícitos.



```julia

# Em vez de um signal global, passe as ações colaterais como argumentos



function create_order(params; on_success=[])

    Repo.transaction() do

        # 1. Salva Pedido

        order = Repo.insert(...)

        

        # 2. Executa Hooks explicitamente

        for hook in on_success

            hook(order)

        end

    end

end



# Uso:

# create_order(params, on_success=[

#    order -> Email.send_receipt(order),

#    order -> Inventory.decrement(order)

# ])

```



---



**Suindara Framework** - Construído para ser simples, rápido e explícito.
