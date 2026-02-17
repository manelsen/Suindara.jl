"""
    module AssociationModule

Funções para carregar associações (has_many, belongs_to) eficientemente,
evitando N+1 queries. Cada preload faz exatamente 1 query adicional.
"""
module AssociationModule

using ..Repo

export preload_has_many, preload_belongs_to

"""
    extract_ids(rows, key::Symbol) :: Vector

Extrai valores únicos de uma coluna, filtrando nulos. Função pura.
"""
function extract_ids(rows::Vector, key::Symbol)::Vector
    ids = []
    for row in rows
        val = getproperty(row, key)
        if val !== nothing && val !== missing
            push!(ids, val)
        end
    end
    return unique(ids)
end

"""
    build_lookup(rows, key::Symbol) :: Dict

Cria Dict[valor_da_chave => row] para lookup O(1). Função pura.
"""
function build_lookup(rows::Vector, key::Symbol)::Dict
    lookup = Dict()
    for row in rows
        k = getproperty(row, key)
        lookup[k] = row
    end
    return lookup
end

"""
    build_group(rows, key::Symbol) :: Dict

Agrupa rows por valor de uma chave. Função pura.
"""
function build_group(rows::Vector, key::Symbol)::Dict
    groups = Dict()
    for row in rows
        k = getproperty(row, key)
        if !haskey(groups, k)
            groups[k] = []
        end
        push!(groups[k], row)
    end
    return groups
end

"""
    preload_has_many(parents, assoc_name, child_table, foreign_key; parent_key=:id)

Carrega filhos (1 query) e anexa como assoc_name em cada parent.
"""
function preload_has_many(parents::Vector, assoc_name::Symbol, child_table::String, foreign_key::String; parent_key::Symbol=:id)
    if isempty(parents)
        return []
    end

    parent_ids = extract_ids(parents, parent_key)
    if isempty(parent_ids)
        return [merge(Dict(pairs(p)), Dict(assoc_name => [])) for p in parents]
    end

    placeholders = join(["?" for _ in parent_ids], ",")
    children = Repo.query("SELECT * FROM $child_table WHERE $foreign_key IN ($placeholders)", parent_ids)

    groups = build_group(children, Symbol(foreign_key))

    result = []
    for parent in parents
        pid = getproperty(parent, parent_key)
        kids = get(groups, pid, [])
        push!(result, merge(Dict(pairs(parent)), Dict(assoc_name => kids)))
    end
    return result
end

"""
    preload_belongs_to(children_rows, assoc_name, parent_table, foreign_key; parent_key=:id)

Carrega pais (1 query) e anexa como assoc_name em cada child.
"""
function preload_belongs_to(children_rows::Vector, assoc_name::Symbol, parent_table::String, foreign_key::String; parent_key::Symbol=:id)
    if isempty(children_rows)
        return []
    end

    fk_ids = extract_ids(children_rows, Symbol(foreign_key))
    if isempty(fk_ids)
        return [merge(Dict(pairs(c)), Dict(assoc_name => nothing)) for c in children_rows]
    end

    pk_col = String(parent_key)
    placeholders = join(["?" for _ in fk_ids], ",")
    parents = Repo.query("SELECT * FROM $parent_table WHERE $pk_col IN ($placeholders)", fk_ids)

    lookup = build_lookup(parents, parent_key)

    result = []
    for child in children_rows
        fk_val = getproperty(child, Symbol(foreign_key))
        parent = (fk_val !== nothing && fk_val !== missing) ? get(lookup, fk_val, nothing) : nothing
        push!(result, merge(Dict(pairs(child)), Dict(assoc_name => parent)))
    end
    return result
end

end # module
