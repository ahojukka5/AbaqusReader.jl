# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader: create_surface_element, create_surface_elements

@testset "create surface element from voluminal element surface" begin
    element = create_surface_element(:Tet4, :S1, [8, 9, 10, 2])
    @test element == (:Tri3, [8, 10, 9])
end

@testset "create surface elements from voluminal element surface" begin
    mesh = Dict(
        "elements" => Dict(16 => [8, 9, 10, 2]),
        "element_types" => Dict(16 => :Tet4),
        "surface_sets" => Dict("LOAD" => [(16, :S1)]))
    elements = create_surface_elements(mesh, "LOAD")
    @test elements[1] == (:Tri3, [8,10,9])
end

@testset "throw error if unknown element or side defined" begin
    @test_throws(Exception, create_surface_element(:Tet5, :S1, [8, 9, 10, 2]))
    @test_throws(Exception, create_surface_element(:Tet4, :S5, [8, 9, 10, 2]))
end

@testset "surface extraction for wedge, hex20, and shell elements" begin
    # Wedge6: faces 1..3 are quads, 4..5 are tris
    wedge_elem = create_surface_element(:Wedge6, :S1, [1, 2, 3, 4, 5, 6])
    @test wedge_elem == (:Quad4, [1, 4, 5, 2])
    wedge_tri = create_surface_element(:Wedge6, :S5, [1, 2, 3, 4, 5, 6])
    @test wedge_tri == (:Tri3, [4, 6, 5])

    # Wedge15: quadratic faces
    wedge15_quad = create_surface_element(:Wedge15, :S2,
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
    @test wedge15_quad == (:Quad8, [2, 5, 6, 3, 12, 13, 14, 9])
    wedge15_tri = create_surface_element(:Wedge15, :S4,
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
    @test wedge15_tri == (:Tri6, [1, 2, 3, 8, 9, 7])

    # Hex20: quadratic quads
    hex20_face = create_surface_element(:Hex20, :S1,
        collect(1:20))
    @test hex20_face == (:Quad8, [1, 2, 3, 4, 9, 10, 11, 12])

    # Shells: edge extraction as segments
    tri6_edge = create_surface_element(:Tri6, :S2, [1, 2, 3, 4, 5, 6])
    @test tri6_edge == (:Seg3, [2, 3, 5])
    quad8_edge = create_surface_element(:Quad8, :S4, [1, 2, 3, 4, 5, 6, 7, 8])
    @test quad8_edge == (:Seg3, [4, 1, 8])
end
