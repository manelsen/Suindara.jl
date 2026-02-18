using Test
using Suindara

@testset "@schema Macro" begin
    @schema Product "products" begin
        field(:title, String)
        field(:price, Float64)
    end

    @test Product <: Any
    @test fieldnames(Product) == (:id, :title, :price)
    
    # Test metadata registration
    @test table_name(Product) == "products"
    @test schema(Product) == [:title, :price]

    # Test constructor from dict
    p = Product(Dict("title" => "Book", "price" => 29.99))
    @test p.title == "Book"
    @test p.price == 29.99
    @test p.id === nothing
end
