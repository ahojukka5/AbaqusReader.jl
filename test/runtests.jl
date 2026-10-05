# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader
using Test

@testset "AbaqusReader.jl" begin
    @testset "test_element_database" begin
        include("test_element_database.jl")
    end
    @testset "test_register_element" begin
        include("test_register_element.jl")
    end
    @testset "test_solid_section_area" begin
        include("test_solid_section_area.jl")
    end
    @testset "test_parse_mesh" begin
        include("test_parse_mesh.jl")
    end
    @testset "test_parse_model" begin
        include("test_parse_model.jl")
    end
    @testset "test_model_sections" begin
        include("test_model_sections.jl")
    end
    @testset "test_create_surface_elements" begin
        include("test_create_surface_elements.jl")
    end
    @testset "test_element_boundary" begin
        include("test_element_boundary.jl")
    end
    @testset "test_download" begin
        include("test_download.jl")
    end
    @testset "test_parse_t2d2" begin
        include("test_parse_t2d2.jl")
    end
    @testset "test_parse_beams" begin
        include("test_parse_beams.jl")
    end
    @testset "test_multiple_parts" begin
        include("test_multiple_parts.jl")
    end
end
