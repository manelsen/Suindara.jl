using Test
using Suindara

@testset "Changeset Advanced Validations" begin

    @testset "validate_format: aceita valor que bate com regex" begin
        ch = cast(Dict("email" => "user@test.com"), [:email])
        ch = validate_format(ch, :email, r"^[^@]+@[^@]+\.[^@]+$")
        @test ch.valid == true
        @test isempty(ch.errors)
    end

    @testset "validate_format: rejeita valor que não bate" begin
        ch = cast(Dict("email" => "invalid"), [:email])
        ch = validate_format(ch, :email, r"^[^@]+@[^@]+\.[^@]+$")
        @test ch.valid == false
        @test haskey(ch.errors, :email)
        @test any(e -> contains(e, "format"), ch.errors[:email])
    end

    @testset "validate_format: ignora campo ausente" begin
        ch = cast(Dict("name" => "Ana"), [:name, :email])
        ch = validate_format(ch, :email, r".*")
        @test ch.valid == true
    end

    @testset "validate_length: aceita string dentro do range" begin
        ch = cast(Dict("name" => "Julia"), [:name])
        ch = validate_length(ch, :name, min=2, max=50)
        @test ch.valid == true
    end

    @testset "validate_length: rejeita string curta demais" begin
        ch = cast(Dict("name" => "J"), [:name])
        ch = validate_length(ch, :name, min=2, max=50)
        @test ch.valid == false
        @test haskey(ch.errors, :name)
    end

    @testset "validate_length: rejeita string longa demais" begin
        ch = cast(Dict("name" => "A"^51), [:name])
        ch = validate_length(ch, :name, min=2, max=50)
        @test ch.valid == false
    end

    @testset "validate_length: ignora campo ausente" begin
        ch = cast(Dict("x" => "y"), [:x, :name])
        ch = validate_length(ch, :name, min=1, max=10)
        @test ch.valid == true
    end

    @testset "validate_inclusion: aceita valor na lista" begin
        ch = cast(Dict("role" => "admin"), [:role])
        ch = validate_inclusion(ch, :role, ["admin", "user", "guest"])
        @test ch.valid == true
    end

    @testset "validate_inclusion: rejeita valor fora da lista" begin
        ch = cast(Dict("role" => "hacker"), [:role])
        ch = validate_inclusion(ch, :role, ["admin", "user", "guest"])
        @test ch.valid == false
        @test haskey(ch.errors, :role)
        @test any(e -> contains(e, "inclusion"), ch.errors[:role])
    end

    @testset "validate_inclusion: ignora campo ausente" begin
        ch = cast(Dict("x" => "y"), [:x, :role])
        ch = validate_inclusion(ch, :role, ["a", "b"])
        @test ch.valid == true
    end

    @testset "composição: múltiplas validações encadeadas" begin
        ch = cast(Dict("email" => "bad", "role" => "hacker"), [:email, :role])
        ch = validate_format(ch, :email, r"^[^@]+@[^@]+\.[^@]+$")
        ch = validate_inclusion(ch, :role, ["admin", "user"])
        @test ch.valid == false
        @test length(ch.errors) == 2
    end

end
