"""
    module RepoAdapterModule

Define a interface abstrata para adapters de banco de dados.
Cada adapter concreto (SQLite, PostgreSQL) implementa esses métodos.
"""
module RepoAdapterModule

export AbstractAdapter, adapter_connect!, adapter_query, adapter_execute!,
       adapter_transaction, adapter_get_conn, adapter_release_conn!,
       create_adapter, convert_placeholders, register_adapter!

"""
    abstract type AbstractAdapter

Interface base para todos os adapters de banco de dados.
Adapters concretos devem implementar:
- `adapter_connect!(adapter, connection_string)`
- `adapter_query(adapter, sql, params) :: Vector{NamedTuple}`
- `adapter_execute!(adapter, sql, params)`
- `adapter_transaction(adapter, f::Function)`
- `adapter_get_conn(adapter)`
- `adapter_release_conn!(adapter, conn)`
"""
abstract type AbstractAdapter end

# --- Interface (devem ser implementados por cada adapter) ---

function adapter_connect!(adapter::AbstractAdapter, connection_string::String)
    error("adapter_connect! not implemented for $(typeof(adapter))")
end

function adapter_query(adapter::AbstractAdapter, sql::String, params=())::Vector
    error("adapter_query not implemented for $(typeof(adapter))")
end

function adapter_execute!(adapter::AbstractAdapter, sql::String, params=())
    error("adapter_execute! not implemented for $(typeof(adapter))")
end

function adapter_transaction(adapter::AbstractAdapter, f::Function)
    error("adapter_transaction not implemented for $(typeof(adapter))")
end

function adapter_get_conn(adapter::AbstractAdapter)
    error("adapter_get_conn not implemented for $(typeof(adapter))")
end

function adapter_release_conn!(adapter::AbstractAdapter, conn)
    error("adapter_release_conn! not implemented for $(typeof(adapter))")
end

"""
    adapter_sql_type(adapter::AbstractAdapter, abstract_type::Symbol)::String

Maps an abstract Julia-native type (e.g. `:string`, `:datetime`) to the database-specific SQL type.
"""
function adapter_sql_type(adapter::AbstractAdapter, abstract_type::Symbol)::String
    error("adapter_sql_type not implemented for $(typeof(adapter))")
end


# --- Placeholder Conversion ---

"""
    convert_placeholders(sql::String, style::Symbol) :: String

Converte placeholders `?` para o estilo do banco.
- `:question` → mantém `?` (SQLite)
- `:dollar` → converte `?` para `\$1, \$2, ...` (PostgreSQL)
"""
function convert_placeholders(sql::String, style::Symbol)::String
    if style == :question
        return sql
    elseif style == :dollar
        counter = Ref(0)
        return replace(sql, "?" => function(_)
            counter[] += 1
            return "\$$(counter[])"
        end)
    else
        error("Unknown placeholder style: $style")
    end
end

# --- Factory ---

# Registry para adapters disponíveis
const _ADAPTER_REGISTRY = Dict{Symbol, Type}()

"""
    register_adapter!(name::Symbol, adapter_type::Type)

Registra um tipo de adapter no registry global.
"""
function register_adapter!(name::Symbol, adapter_type::Type)
    _ADAPTER_REGISTRY[name] = adapter_type
end

"""
    create_adapter(name::Symbol) :: AbstractAdapter

Cria uma instância do adapter pelo nome.
"""
function create_adapter(name::Symbol)::AbstractAdapter
    if !haskey(_ADAPTER_REGISTRY, name)
        available = join(keys(_ADAPTER_REGISTRY), ", ")
        error("Unknown adapter: :$name. Available: $available. " *
              "For PostgreSQL, ensure LibPQ.jl is installed: ] add LibPQ")
    end
    return _ADAPTER_REGISTRY[name]()
end

end # module
