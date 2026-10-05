# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader: element_boundary, element_mapping

@testset "volume boundaries keep Abaqus side order" begin
    tet4 = element_boundary(:Tet4)
    @test tet4.kind === :volume_faces
    @test tet4.linearized == false
    @test tet4.faces == [[1, 3, 2], [1, 2, 4], [2, 3, 4], [1, 4, 3]]

    hex8 = element_boundary(:Hex8)
    @test hex8.kind === :volume_faces
    @test hex8.linearized == false
    @test hex8.faces == [
        [1, 2, 3, 4],
        [5, 8, 7, 6],
        [1, 5, 6, 2],
        [2, 6, 7, 3],
        [3, 7, 8, 4],
        [4, 8, 5, 1],
    ]

    wedge6 = element_boundary(:Wedge6)
    @test wedge6.kind === :volume_faces
    @test wedge6.linearized == false
    @test wedge6.faces == [
        [1, 4, 5, 2],
        [2, 5, 6, 3],
        [3, 6, 4, 1],
        [1, 2, 3],
        [4, 6, 5],
    ]
end

@testset "quadratic volume faces drop midside nodes" begin
    tet10 = element_boundary(:Tet10)
    @test tet10.kind === :volume_faces
    @test tet10.linearized == true
    @test tet10.faces == [
        element_mapping[:Tet10][side][2][1:3] for side in (:S1, :S2, :S3, :S4)
    ]

    hex20 = element_boundary(:Hex20)
    @test hex20.kind === :volume_faces
    @test hex20.linearized == true
    @test hex20.faces == [
        element_mapping[:Hex20][side][2][1:4] for side in (:S1, :S2, :S3, :S4, :S5, :S6)
    ]
    @test all(node <= 8 for face in hex20.faces for node in face)
end

@testset "shell and membrane elements return one corner face" begin
    tri3 = element_boundary(:Tri3)
    @test tri3.kind === :surface_face
    @test tri3.linearized == false
    @test tri3.faces == [[1, 2, 3]]

    tri6 = element_boundary(:Tri6)
    @test tri6.kind === :surface_face
    @test tri6.linearized == true
    @test tri6.faces == [[
        element_mapping[:Tri6][side][2][1] for side in (:S1, :S2, :S3)
    ]]

    quad4 = element_boundary(:Quad4)
    @test quad4.kind === :surface_face
    @test quad4.linearized == false
    @test quad4.faces == [[1, 2, 3, 4]]

    quad8 = element_boundary(:Quad8)
    @test quad8.kind === :surface_face
    @test quad8.linearized == true
    @test quad8.faces == [[
        element_mapping[:Quad8][side][2][1] for side in (:S1, :S2, :S3, :S4)
    ]]

    quad9 = element_boundary(:Quad9)
    @test quad9.kind === :surface_face
    @test quad9.linearized == true
    @test quad9.faces == [[1, 2, 3, 4]]
end

@testset "lines, points, and unknown topologies" begin
    for topology in (:Poi1, :Seg2, :Seg3)
        boundary = element_boundary(topology)
        @test boundary.kind === :non_surface
        @test boundary.linearized == false
        @test isempty(boundary.faces)
    end

    unknown = element_boundary(:NotAnElement)
    @test unknown.kind === :unsupported
    @test unknown.linearized == false
    @test isempty(unknown.faces)
end
