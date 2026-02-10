# examples/cookbook_check.jl
using Pkg
Pkg.activate(".")

using Test
using Suindara
using Suindara.Repo
using Suindara.ConnModule
using Suindara.ChangesetModule
using Suindara.MigrationModule
using HTTP
using JSON3
using Dates

# ==============================================================================
# 0. SETUP & MOCKS
# ==============================================================================

const DB_PATH = "cookbook_test.db"
if isfile(DB_PATH)
    rm(DB_PATH)
end

Repo.connect(DB_PATH)

# Mocking SHA for the example (since it's not a dependency)
module SHA_Mock
    sha256(s) = "hashed_$(s)"
    bytes2hex(s) = s
end

# ==============================================================================
# 1. IMPLEMENTING RECIPE: CONTEXTS (Accounts)
# ==============================================================================
println("
🍳 [1/4] Testing Contexts & Architecture...")

module Accounts
    using Suindara # Needed for ResourceModule
    using Suindara.Repo
    using Suindara.ChangesetModule
    using ..SHA_Mock # Using our mock

    struct User
        id::Int
        email::String
        password_hash::String
    end

    # Schema for validation
    Suindara.ResourceModule.schema(::Type{User}) = [:email, :password]
    Suindara.ResourceModule.table_name(::Type{User}) = "users"

    function register_user(attrs::Dict)
        # 1. Basic Validation
        ch = cast(attrs, [:email, :password])
        ch = validate_required(ch, [:email, :password])
        
        if !ch.valid return ch end

        # 2. Business Logic: Hash password
        pass = get(ch.changes, :password, "")
        ch.changes[:password_hash] = SHA_Mock.sha256(pass)
        delete!(ch.changes, :password) # Never save raw password!

        # 3. Persistence
        try
            Repo.insert(ch, "users")
            return ch
        catch e
            ch.valid = false
            ch.errors[:email] = "Database Error: $(e)"
            return ch
        end
    end
end

# Setup Table for Accounts
create_table("users", [
    "id INTEGER PRIMARY KEY",
    "email TEXT UNIQUE NOT NULL",
    "password_hash TEXT NOT NULL"
])

@testset "Recipe: Accounts Context" begin
    # Test Registration
    payload = Dict("email" => "cook@test.com", "password" => "secret123")
    result = Accounts.register_user(payload)
    
    @test result.valid == true
    @test result.changes[:password_hash] == "hashed_secret123"
    @test !haskey(result.changes, :password)
    
    # Check DB
    user_row = Repo.get_one("users", "cook@test.com", pk="email")
    @test user_row.email == "cook@test.com"
    @test user_row.password_hash == "hashed_secret123"
end

# ==============================================================================
# 2. IMPLEMENTING RECIPE: PLUGS & MIDDLEWARE
# ==============================================================================
println("
🍳 [2/4] Testing Plugs & Middleware...")

function plug_check_auth(conn::Conn)
    auth_header = HTTP.header(conn.request, "Authorization")
    if auth_header == "Bearer secret_123"
        assign(conn, :user_id, 42)
        return conn
    else
        return halt!(conn, 401, "Access Denied")
    end
end

function plug_cors(conn::Conn)
    push!(conn.resp_headers, "Access-Control-Allow-Origin" => "*")
    return conn
end

@testset "Recipe: Plugs" begin
    # Case 1: Unauthorized
    req = HTTP.Request("GET", "/")
    conn = Conn(req)
    conn = plug_check_auth(conn)
    @test conn.halted == true
    @test conn.status == 401
    
    # Case 2: Authorized
    req_auth = HTTP.Request("GET", "/", ["Authorization" => "Bearer secret_123"])
    conn = Conn(req_auth)
    conn = plug_check_auth(conn)
    @test conn.halted == false
    @test conn.assigns[:user_id] == 42
    
    # Case 3: CORS
    conn = plug_cors(conn)
    cors_header = [v for (k,v) in conn.resp_headers if k == "Access-Control-Allow-Origin"]
    @test !isempty(cors_header)
    @test cors_header[1] == "*"
end

# ==============================================================================
# 3. IMPLEMENTING RECIPE: DATABASE TRANSACTIONS
# ==============================================================================
println("
🍳 [3/4] Testing Database Transactions...")

create_table("wallets", [
    "id INTEGER PRIMARY KEY",
    "balance INTEGER"
])

Repo.execute("INSERT INTO wallets (id, balance) VALUES (1, 100)")
Repo.execute("INSERT INTO wallets (id, balance) VALUES (2, 50)")

function transfer_credits(from_id, to_id, amount)
    Repo.transaction() do
        Repo.execute("UPDATE wallets SET balance = balance - ? WHERE id = ?", [amount, from_id])
        Repo.execute("UPDATE wallets SET balance = balance + ? WHERE id = ?", [amount, to_id])
        
        # Simulate Error to test Rollback
        if amount > 1000
            error("Insufficient funds trigger")
        end
    end
end

@testset "Recipe: Transactions" begin
    # Successful Transfer
    transfer_credits(1, 2, 30)
    w1 = Repo.get_one("wallets", 1)
    w2 = Repo.get_one("wallets", 2)
    @test w1.balance == 70
    @test w2.balance == 80
    
    # Failed Transfer (Rollback)
    try
        transfer_credits(1, 2, 5000) # Should fail
    catch
        # Expected
    end
    
    # Balances should remain unchanged from previous step
    w1_after = Repo.get_one("wallets", 1)
    w2_after = Repo.get_one("wallets", 2)
    @test w1_after.balance == 70
    @test w2_after.balance == 80
end

# ==============================================================================
# 4. IMPLEMENTING RECIPE: PAGINATION & CUSTOM QUERIES
# ==============================================================================
println("
🍳 [4/4] Testing Pagination & Advanced Queries...")

# Populate data
for i in 1:25
    Repo.execute("INSERT INTO wallets (balance) VALUES (?)", [i])
end

function paginate(query::String, page::Int, per_page::Int)
    offset = (page - 1) * per_page
    limit_query = "$query LIMIT $per_page OFFSET $offset"
    rows = Repo.query(limit_query)
    # Materialize explicitly to avoid "row is no longer valid"
    return [NamedTuple(Symbol(k) => getproperty(r, Symbol(k)) for k in propertynames(r)) for r in rows]
end

@testset "Recipe: Pagination" begin
    # Page 1 (items 1-10) - Note: wallets table has mixed data now
    results = paginate("SELECT * FROM wallets ORDER BY id", 1, 10)
    @test length(results) == 10
    
    # Page 2
    results_p2 = paginate("SELECT * FROM wallets ORDER BY id", 2, 10)
    @test length(results_p2) == 10
    @test results_p2[1].id != results[1].id
end

println("
✅ All Cookbook Recipes Verified!")
rm(DB_PATH)
