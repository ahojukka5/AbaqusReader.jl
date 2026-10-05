# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader: abaqus_parse_mesh, boundary_faces, element_boundary

function side_table_faces(topology::Symbol, connectivity)
    return [
        [Int(connectivity[position]) for position in face]
        for face in element_boundary(topology).faces
    ]
end

function by_sorted_nodes(faces)
    return sort(collect(faces); by=face -> Tuple(sort(face)))
end

@testset "one tetrahedron keeps side-table order" begin
    mesh = Dict(
        "elements" => Dict(1 => [1, 2, 3, 4]),
        "element_types" => Dict(1 => :Tet4),
    )
    surface = boundary_faces(mesh)
    expected = by_sorted_nodes(side_table_faces(:Tet4, [1, 2, 3, 4]))
    @test [face.nodes for face in surface.faces] == expected
    @test all(face.from_volume && face.element_id == 1 && face.topology === :Tet4
        for face in surface.faces)
    @test surface.volume_boundary_face_count == 4
    @test surface.surface_element_face_count == 0
    @test surface.nonmanifold_face_count == 0
    @test surface.linearized_topologies == String[]
    @test isempty(surface.skipped_topologies)
    @test isempty(surface.unsupported_topologies)
    @test all(length(face.nodes) == 3 for face in surface.faces)
end

@testset "inward side-table winding is not flipped" begin
    # S1 of [1, 3, 2, 4] is global [1, 2, 3], inward for the standard corners.
    mesh = Dict(
        "elements" => Dict(1 => [1, 3, 2, 4]),
        "element_types" => Dict(1 => :Tet4),
    )
    surface = boundary_faces(mesh)
    expected = by_sorted_nodes(side_table_faces(:Tet4, [1, 3, 2, 4]))
    @test [face.nodes for face in surface.faces] == expected
    base = only(face for face in surface.faces if sort(face.nodes) == [1, 2, 3])
    @test base.nodes == [1, 2, 3]
end

@testset "quadratic tetrahedron matches on corners only" begin
    mesh = Dict(
        "elements" => Dict(1 => collect(1:10)),
        "element_types" => Dict(1 => :Tet10),
    )
    surface = boundary_faces(mesh)
    @test [face.nodes for face in surface.faces] ==
        by_sorted_nodes(side_table_faces(:Tet10, collect(1:10)))
    @test surface.linearized_topologies == ["Tet10"]
    @test all(node <= 4 for face in surface.faces for node in face.nodes)
end

@testset "shared volume face is omitted and a triple face is counted" begin
    shared = Dict(
        "elements" => Dict(
            1 => [1, 2, 3, 4],
            2 => [1, 3, 2, 5],
        ),
        "element_types" => Dict(1 => :Tet4, 2 => :Tet4),
    )
    shared_surface = boundary_faces(shared)
    @test shared_surface.volume_boundary_face_count == 6
    @test shared_surface.nonmanifold_face_count == 0
    @test length(shared_surface.faces) == 6
    @test count(face -> face.element_id == 1, shared_surface.faces) == 3
    @test count(face -> face.element_id == 2, shared_surface.faces) == 3
    @test !any(face -> sort(face.nodes) == [1, 2, 3], shared_surface.faces)

    nonmanifold = Dict(
        "elements" => Dict(
            1 => [1, 2, 3, 4],
            2 => [1, 3, 2, 5],
            3 => [1, 2, 3, 6],
        ),
        "element_types" => Dict(1 => :Tet4, 2 => :Tet4, 3 => :Tet4),
    )
    nonmanifold_surface = boundary_faces(nonmanifold)
    @test nonmanifold_surface.volume_boundary_face_count == 9
    @test nonmanifold_surface.nonmanifold_face_count == 1
    @test length(nonmanifold_surface.faces) == 9
    @test !any(face -> sort(face.nodes) == [1, 2, 3], nonmanifold_surface.faces)
end

@testset "two bricks omit the shared quadrilateral without splitting it" begin
    mesh = Dict(
        "elements" => Dict(
            1 => [1, 2, 3, 4, 5, 6, 7, 8],
            2 => [5, 6, 7, 8, 9, 10, 11, 12],
        ),
        "element_types" => Dict(1 => :Hex8, 2 => :Hex8),
    )
    surface = boundary_faces(mesh)
    @test surface.volume_boundary_face_count == 10
    @test surface.nonmanifold_face_count == 0
    @test length(surface.faces) == 10
    @test !any(face -> sort(face.nodes) == [5, 6, 7, 8], surface.faces)
    @test any(face -> face.nodes == [1, 2, 3, 4] && face.element_id == 1,
        surface.faces)
    @test all(face.from_volume for face in surface.faces)
    @test any(length(face.nodes) == 4 for face in surface.faces)
end

@testset "a wedge keeps triangles and quadrilaterals" begin
    connectivity = [1, 2, 3, 4, 5, 6]
    mesh = Dict(
        "elements" => Dict(7 => connectivity),
        "element_types" => Dict(7 => :Wedge6),
    )
    surface = boundary_faces(mesh)
    @test [face.nodes for face in surface.faces] ==
        by_sorted_nodes(side_table_faces(:Wedge6, connectivity))
    @test surface.volume_boundary_face_count == 5
    @test count(face -> length(face.nodes) == 3, surface.faces) == 2
    @test count(face -> length(face.nodes) == 4, surface.faces) == 3
    @test all(face.element_id == 7 for face in surface.faces)
end

@testset "shells are not matched to each other or to a volume face" begin
    shells = Dict(
        "elements" => Dict(1 => [1, 2, 3, 4], 2 => [1, 2, 3, 4]),
        "element_types" => Dict(1 => :Quad4, 2 => :Quad4),
    )
    shell_surface = boundary_faces(shells)
    @test [face.nodes for face in shell_surface.faces] == [[1, 2, 3, 4], [1, 2, 3, 4]]
    @test [face.element_id for face in shell_surface.faces] == [1, 2]
    @test shell_surface.volume_boundary_face_count == 0
    @test shell_surface.surface_element_face_count == 2
    @test shell_surface.nonmanifold_face_count == 0
    @test all(!face.from_volume for face in shell_surface.faces)

    mixed = Dict(
        "elements" => Dict(
            1 => [1, 2, 3, 4, 5, 6, 7, 8],
            2 => [1, 2, 3, 4],
        ),
        "element_types" => Dict(1 => :Hex8, 2 => :Quad4),
    )
    mixed_surface = boundary_faces(mixed)
    @test mixed_surface.volume_boundary_face_count == 6
    @test mixed_surface.surface_element_face_count == 1
    @test count(face -> face.nodes == [1, 2, 3, 4], mixed_surface.faces) == 2
    shell = only(face for face in mixed_surface.faces if !face.from_volume)
    @test shell.element_id == 2
    @test shell.topology === :Quad4
end

@testset "omissions, linearization, and a string topology" begin
    mesh = Dict(
        "elements" => Dict(
            1 => [1, 2, 3, 4],
            2 => [10, 11, 12, 13, 14, 15, 16, 17, 18],
            3 => [20, 21],
            4 => [30],
            5 => [1],
            6 => [1, 2],
            8 => [1, 2, 3],
        ),
        "element_types" => Dict(
            1 => :Tet4,
            2 => :Quad9,
            3 => :Seg2,
            4 => :Poi1,
            6 => :NotAnElement,
            8 => "Tri3",
        ),
    )
    surface = boundary_faces(mesh)
    @test surface.volume_boundary_face_count == 4
    @test surface.surface_element_face_count == 2
    @test surface.skipped_topologies == Dict("Seg2" => 1, "Poi1" => 1)
    @test surface.unsupported_topologies == Dict("missing" => 1, "NotAnElement" => 1)
    @test surface.linearized_topologies == ["Quad9"]
    @test length(surface.faces) == 6
    quad = only(face for face in surface.faces if face.element_id == 2)
    @test quad.nodes == [10, 11, 12, 13]
    @test quad.topology === :Quad9
    @test !quad.from_volume
    tri = surface.faces[end]
    @test tri.topology === :Tri3
    @test tri.element_id == 8
    @test tri.nodes == [1, 2, 3]
end

@testset "parsed deck classifies solids and omits the beam" begin
    mesh = abaqus_parse_mesh("""
    *Node
    1, 0, 0, 0
    2, 1, 0, 0
    3, 0, 1, 0
    4, 0, 0, 1
    5, 0, 0, -1
    *Element, type=C3D4
    1, 1, 2, 3, 4
    2, 1, 3, 2, 5
    *Element, type=B31
    3, 1, 2
    """; verbose=false)
    surface = boundary_faces(mesh)
    @test surface.volume_boundary_face_count == 6
    @test surface.surface_element_face_count == 0
    @test surface.skipped_topologies == Dict("Seg2" => 1)
    @test surface.linearized_topologies == String[]
    @test length(surface.faces) == 6
    @test !any(face -> sort(face.nodes) == [1, 2, 3], surface.faces)
end

@testset "short connectivity fails and a missing node does not" begin
    missing = Dict(
        "elements" => Dict(1 => [1, 2, 3, 4]),
        "element_types" => Dict(1 => :Tet4),
    )
    missing_surface = boundary_faces(missing)
    @test missing_surface.volume_boundary_face_count == 4
    @test any(face -> 4 in face.nodes, missing_surface.faces)

    short_volume = Dict(
        "elements" => Dict(1 => [1, 2, 3]),
        "element_types" => Dict(1 => :Tet4),
    )
    @test_throws ArgumentError("element 1 has too few nodes for Tet4") boundary_faces(short_volume)

    short_shell = Dict(
        "elements" => Dict(1 => [1, 2, 3]),
        "element_types" => Dict(1 => :Quad4),
    )
    @test_throws ArgumentError("element 1 has too few nodes for its topology") boundary_faces(short_shell)

    empty = boundary_faces(Dict(
        "elements" => Dict{Int,Vector{Int}}(),
        "element_types" => Dict{Int,Symbol}(),
    ))
    @test isempty(empty.faces)
    @test empty.volume_boundary_face_count == 0
    @test empty.surface_element_face_count == 0
    @test empty.nonmanifold_face_count == 0
    @test empty.linearized_topologies == String[]
end
