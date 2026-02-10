using Test
using Suindara

@testset "Changeset Unit Tests" begin
    
    @testset "cast" begin
        params = Dict("name" => "Alice", "age" => 30, "email" => "alice@example.com")
        ch = cast(params, [:name, :age, :email])
        
        @test ch.valid == true
        @test ch.changes[:name] == "Alice"
        @test ch.changes[:age] == 30
    end

    @testset "cast with filtering" begin
        params = Dict("name" => "Bob", "age" => "30", "admin" => true)
        allowed = [:name, :age]
        ch = cast(params, allowed)
        
        @test ch.valid == true
        @test haskey(ch.changes, :name)
        @test !haskey(ch.changes, :admin)
    end

    @testset "validate_required" begin
        params = Dict("name" => "Charlie")
        ch = cast(params, [:name, :email])
        
        # Should be valid initially (cast doesn't validate)
        @test ch.valid == true
        
        # Now validate
        ch = validate_required(ch, [:name, :email])
        
        @test ch.valid == false
        @test haskey(ch.errors, :email)
        @test ch.errors[:email] == ["can't be blank"]
        @test !haskey(ch.errors, :name)
    end
end