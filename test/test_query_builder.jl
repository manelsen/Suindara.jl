using Test
using Suindara

@testset "Query Builder" begin

    @testset "from retorna Query base" begin
        q = Suindara.QueryBuilderModule.from("users")
        @test q isa Suindara.QueryBuilderModule.Query
        @test q.table == "users"
    end

    @testset "where adiciona condição" begin
        q = Suindara.QueryBuilderModule.from("users")
        q = Suindara.QueryBuilderModule.where(q, "active = ?", [1])
        @test length(q.conditions) == 1
        @test q.params == [1]
    end

    @testset "where encadeado com |>" begin
        q = Suindara.QueryBuilderModule.from("users") |>
            q -> Suindara.QueryBuilderModule.where(q, "active = ?", [1]) |>
            q -> Suindara.QueryBuilderModule.where(q, "role = ?", ["admin"])
        @test length(q.conditions) == 2
        @test q.params == Any[1, "admin"]
    end

    @testset "select define colunas" begin
        q = Suindara.QueryBuilderModule.from("users")
        q = Suindara.QueryBuilderModule.select(q, ["name", "email"])
        @test q.columns == ["name", "email"]
    end

    @testset "limit e offset" begin
        q = Suindara.QueryBuilderModule.from("users")
        q = Suindara.QueryBuilderModule.qb_limit(q, 10)
        q = Suindara.QueryBuilderModule.qb_offset(q, 20)
        @test q.limit_val == 10
        @test q.offset_val == 20
    end

    @testset "order_by" begin
        q = Suindara.QueryBuilderModule.from("users")
        q = Suindara.QueryBuilderModule.order_by(q, "name ASC")
        @test q.order == "name ASC"
    end

    @testset "to_sql gera SQL correto para SELECT simples" begin
        q = Suindara.QueryBuilderModule.from("users")
        sql, params = Suindara.QueryBuilderModule.to_sql(q)
        @test sql == "SELECT * FROM users"
        @test isempty(params)
    end

    @testset "to_sql gera SQL com WHERE" begin
        q = Suindara.QueryBuilderModule.from("users") |>
            q -> Suindara.QueryBuilderModule.where(q, "active = ?", [1])
        sql, params = Suindara.QueryBuilderModule.to_sql(q)
        @test sql == "SELECT * FROM users WHERE active = ?"
        @test params == [1]
    end

    @testset "to_sql gera SQL completo" begin
        QBM = Suindara.QueryBuilderModule
        q = QBM.from("users") |>
            q -> QBM.select(q, ["id", "name"]) |>
            q -> QBM.where(q, "active = ?", [1]) |>
            q -> QBM.where(q, "role = ?", ["admin"]) |>
            q -> QBM.order_by(q, "name ASC") |>
            q -> QBM.qb_limit(q, 10) |>
            q -> QBM.qb_offset(q, 5)
        sql, params = QBM.to_sql(q)
        @test sql == "SELECT id, name FROM users WHERE active = ? AND role = ? ORDER BY name ASC LIMIT 10 OFFSET 5"
        @test params == Any[1, "admin"]
    end

    @testset "all executa query no banco e retorna resultados" begin
        Suindara.Repo.connect(":memory:")
        Suindara.Repo.execute("CREATE TABLE qb_test (id INTEGER PRIMARY KEY, name TEXT, active INTEGER)")
        Suindara.Repo.execute("INSERT INTO qb_test (name, active) VALUES (?, ?)", ["Alice", 1])
        Suindara.Repo.execute("INSERT INTO qb_test (name, active) VALUES (?, ?)", ["Bob", 0])

        QBM = Suindara.QueryBuilderModule
        results = QBM.from("qb_test") |>
            q -> QBM.where(q, "active = ?", [1]) |>
            QBM.qb_all

        @test length(results) == 1
        @test results[1].name == "Alice"
    end

end
