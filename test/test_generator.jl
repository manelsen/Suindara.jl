using Test
using Suindara
using Suindara.GeneratorModule

@testset "Generator Tests" begin
    app_name = "test_app"
    
    # Clean up before test
    rm(app_name, recursive=true, force=true)
    
    generate_project(app_name)
    
    @test isdir(app_name)
    @test isdir("$app_name/src/controllers")
    @test isdir("$app_name/db")
    @test isfile("$app_name/Project.toml")
    @test isfile("$app_name/src/$app_name.jl")
    @test isfile("$app_name/src/router.jl")
    @test isfile("$app_name/src/controllers/page_controller.jl")
    @test isfile("$app_name/Dockerfile")
    
    # Check content of a generated file
    content = read("$app_name/src/controllers/page_controller.jl", String)
    @test occursin("Welcome to Suindara on Julia!", content)
    
    # Clean up after test
    rm(app_name, recursive=true, force=true)
end