"""
    module QueryBuilderModule

Query builder composável usando o pipe operator.
Constrói queries SQL de forma segura sem escrever SQL cru.

Uso:
    from("users") |> where("active = ?", [1]) |> qb_limit(10) |> qb_all
"""
module QueryBuilderModule

using ..Repo

export from, where, select, qb_limit, qb_offset, order_by, to_sql, qb_all, Query

"""
    struct Query

Estrutura imutável que representa uma query em construção.
Cada operação retorna uma NOVA Query (imutabilidade funcional).
"""
struct Query
    table::String
    columns::Vector{String}
    conditions::Vector{String}
    params::Vector{Any}
    order::String
    limit_val::Int
    offset_val::Int
end

"""
    from(table::String) :: Query

Cria uma query base para a tabela especificada.
"""
function from(table::String)::Query
    return Query(table, String[], String[], Any[], "", -1, -1)
end

"""
    select(q::Query, cols::Vector{String}) :: Query

Define quais colunas selecionar. Retorna nova Query.
"""
function select(q::Query, cols::Vector{String})::Query
    return Query(q.table, cols, q.conditions, q.params, q.order, q.limit_val, q.offset_val)
end

"""
    where(q::Query, condition::String, params::Vector=[]) :: Query

Adiciona uma condição WHERE. Acumula com AND. Retorna nova Query.
"""
function where(q::Query, condition::String, params::Vector=Any[])::Query
    new_conditions = [q.conditions..., condition]
    new_params = Any[q.params..., params...]
    return Query(q.table, q.columns, new_conditions, new_params, q.order, q.limit_val, q.offset_val)
end

"""
    order_by(q::Query, clause::String) :: Query

Define a cláusula ORDER BY. Retorna nova Query.
"""
function order_by(q::Query, clause::String)::Query
    return Query(q.table, q.columns, q.conditions, q.params, clause, q.limit_val, q.offset_val)
end

"""
    qb_limit(q::Query, n::Int) :: Query

Define o LIMIT. Retorna nova Query. Prefixo qb_ evita conflito com Base.limit.
"""
function qb_limit(q::Query, n::Int)::Query
    return Query(q.table, q.columns, q.conditions, q.params, q.order, n, q.offset_val)
end

"""
    qb_offset(q::Query, n::Int) :: Query

Define o OFFSET. Retorna nova Query.
"""
function qb_offset(q::Query, n::Int)::Query
    return Query(q.table, q.columns, q.conditions, q.params, q.order, q.limit_val, n)
end

"""
    to_sql(q::Query) :: Tuple{String, Vector{Any}}

Converte a Query em uma tupla (sql_string, params_vector). Função pura.
"""
function to_sql(q::Query)::Tuple{String, Vector{Any}}
    cols = isempty(q.columns) ? "*" : join(q.columns, ", ")
    sql = "SELECT $cols FROM $(q.table)"

    if !isempty(q.conditions)
        sql *= " WHERE " * join(q.conditions, " AND ")
    end

    if !isempty(q.order)
        sql *= " ORDER BY $(q.order)"
    end

    if q.limit_val >= 0
        sql *= " LIMIT $(q.limit_val)"
    end

    if q.offset_val >= 0
        sql *= " OFFSET $(q.offset_val)"
    end

    return (sql, q.params)
end

"""
    qb_all(q::Query) :: Vector

Executa a query no banco (via Repo) e retorna os resultados.
"""
function qb_all(q::Query)::Vector
    sql, params = to_sql(q)
    return Repo.query(sql, params)
end

end # module
