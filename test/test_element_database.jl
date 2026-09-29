# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using Test
using AbaqusReader: load_element_database, element_has_nodes, element_has_type, ELEMENT_INFO

@testset "element database" begin
    @testset "load_element_database" begin
        db = load_element_database()
        @test isa(db, Dict{Symbol,Tuple{Int,Symbol}})
        @test !isempty(db)

        # Test some known elements
        @test haskey(db, :C3D4)
        @test haskey(db, :C3D8)
        @test haskey(db, :CPS3)
        @test haskey(db, :S4)
    end

    @testset "element_has_nodes" begin
        # 3D solid elements
        @test element_has_nodes(:C3D4) == 4
        @test element_has_nodes(:C3D8) == 8
        @test element_has_nodes(:C3D10) == 10
        @test element_has_nodes(:C3D20) == 20

        # 2D continuum elements
        @test element_has_nodes(:CPS3) == 3
        @test element_has_nodes(:CPS4) == 4
        @test element_has_nodes(:CPE3) == 3
        @test element_has_nodes(:CPE4) == 4

        # Shell elements
        @test element_has_nodes(:S3) == 3
        @test element_has_nodes(:S4) == 4

        # Membrane elements
        @test element_has_nodes(:M3D4) == 4
        @test element_has_nodes(:M3D4R) == 4

        # Beam/truss elements
        @test element_has_nodes(:T2D2) == 2
        @test element_has_nodes(:B31) == 2
    end

    @testset "element_has_type" begin
        # 3D solid elements
        @test element_has_type(:C3D4) == :Tet4
        @test element_has_type(:C3D8) == :Hex8
        @test element_has_type(:C3D10) == :Tet10
        @test element_has_type(:C3D20) == :Hex20

        # 2D continuum elements (all triangles/quads)
        @test element_has_type(:CPS3) == :Tri3
        @test element_has_type(:CPE3) == :Tri3
        @test element_has_type(:CAX3) == :Tri3
        @test element_has_type(:CPS4) == :Quad4
        @test element_has_type(:CPE4) == :Quad4

        # Shell elements
        @test element_has_type(:S3) == :Tri3
        @test element_has_type(:S4) == :Quad4

        # Membrane elements
        @test element_has_type(:M3D4) == :Quad4
        @test element_has_type(:M3D4R) == :Quad4

        # Beam/truss elements
        @test element_has_type(:T2D2) == :Seg2
        @test element_has_type(:B31) == :Seg2
    end

    @testset "legacy Val API" begin
        # Test backward compatibility with Val-based API
        @test element_has_nodes(Val{:C3D8}) == 8
        @test element_has_type(Val{:C3D8}) == :Hex8
    end

    @testset "ELEMENT_INFO constant" begin
        # Verify the constant is properly loaded
        @test !isempty(ELEMENT_INFO)
        @test haskey(ELEMENT_INFO, :C3D8)
        @test ELEMENT_INFO[:C3D8] == (8, :Hex8)
    end
end
