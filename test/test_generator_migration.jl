using Test
using Suindara
using Suindara.GeneratorModule

@testset "Generator: generate_migration" begin
    # Work in a temp directory to avoid polluting the project
    ORIG_DIR = pwd()
    TEMP_DIR = mktempdir()
    cd(TEMP_DIR)

    try
        @testset "creates db/migrations directory if missing" begin
            @test !isdir("db/migrations")
            generate_migration("first_test")
            @test isdir("db/migrations")
        end

        @testset "creates file with correct naming format" begin
            files = readdir("db/migrations")
            @test length(files) == 1
            # Format: YYYYMMDDHHMMSS_name.jl
            @test occursin(r"^\d{14}_first_test\.jl$", files[1])
        end

        @testset "file contains up() and down() stubs" begin
            files = readdir("db/migrations")
            content = read(joinpath("db/migrations", files[1]), String)
            @test occursin("function up()", content)
            @test occursin("function down()", content)
        end

        @testset "file contains using Suindara.MigrationModule" begin
            files = readdir("db/migrations")
            content = read(joinpath("db/migrations", files[1]), String)
            @test occursin("using Suindara.MigrationModule", content)
        end

        @testset "two sequential calls create two distinct files" begin
            sleep(1.1)  # Ensure different timestamp (second resolution)
            generate_migration("second_test")
            files = readdir("db/migrations")
            @test length(files) == 2
            @test files[1] != files[2]
            @test occursin("first_test", files[1])
            @test occursin("second_test", files[2])
        end
    finally
        cd(ORIG_DIR)
        rm(TEMP_DIR, recursive=true, force=true)
    end
end
