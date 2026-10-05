# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader: abaqus_parse_mesh, boundary_surface

function surface_dot(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

function surface_cross(a, b)
    return (
        a[2] * b[3] - a[3] * b[2],
        a[3] * b[1] - a[1] * b[3],
        a[1] * b[2] - a[2] * b[1],
    )
end

function node_point(nodes, node_id)
    coordinates = nodes[node_id]
    return (
        coordinates[1],
        length(coordinates) >= 2 ? coordinates[2] : 0.0,
        length(coordinates) >= 3 ? coordinates[3] : 0.0,
    )
end

function triangle_winds_outward(nodes, triangle, element_nodes)
    p1 = node_point(nodes, triangle.nodes[1])
    p2 = node_point(nodes, triangle.nodes[2])
    p3 = node_point(nodes, triangle.nodes[3])
    normal = surface_cross(
        (p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]),
        (p3[1] - p1[1], p3[2] - p1[2], p3[3] - p1[3]),
    )
    face_center = (
        (p1[1] + p2[1] + p3[1]) / 3,
        (p1[2] + p2[2] + p3[2]) / 3,
        (p1[3] + p2[3] + p3[3]) / 3,
    )
    element_center = (0.0, 0.0, 0.0)
    for node_id in element_nodes
        point = node_point(nodes, node_id)
        element_center = (
            element_center[1] + point[1],
            element_center[2] + point[2],
            element_center[3] + point[3],
        )
    end
    scale = 1.0 / length(element_nodes)
    element_center = (
        element_center[1] * scale,
        element_center[2] * scale,
        element_center[3] * scale,
    )
    return surface_dot(normal, (
        face_center[1] - element_center[1],
        face_center[2] - element_center[2],
        face_center[3] - element_center[3],
    )) > 0
end

@testset "one tetrahedron keeps side order and outward winding" begin
    nodes = Dict(
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [0.0, 1.0, 0.0],
        4 => [0.0, 0.0, 1.0],
    )
    mesh = Dict(
        "nodes" => nodes,
        "elements" => Dict(1 => [1, 2, 3, 4]),
        "element_types" => Dict(1 => :Tet4),
    )
    surface = boundary_surface(mesh)
    @test [(triangle.nodes, triangle.element_id, triangle.topology)
        for triangle in surface.triangles] == [
        ((1, 3, 2), 1, :Tet4),
        ((1, 2, 4), 1, :Tet4),
        ((1, 4, 3), 1, :Tet4),
        ((2, 3, 4), 1, :Tet4),
    ]
    @test surface.volume_boundary_face_count == 4
    @test surface.surface_element_face_count == 0
    @test surface.nonmanifold_face_count == 0
    @test surface.linearized_topologies == String[]
    @test isempty(surface.skipped_topologies)
    @test isempty(surface.unsupported_topologies)
    @test all(
        triangle_winds_outward(nodes, triangle, [1, 2, 3, 4])
        for triangle in surface.triangles
    )
end

@testset "reversed tetrahedron face is wound outward" begin
    nodes = Dict(
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [0.0, 1.0, 0.0],
        4 => [0.0, 0.0, 1.0],
    )
    mesh = Dict(
        "nodes" => nodes,
        "elements" => Dict(1 => [1, 3, 2, 4]),
        "element_types" => Dict(1 => :Tet4),
    )
    surface = boundary_surface(mesh)
    base = only(filter(
        triangle -> sort(collect(triangle.nodes)) == [1, 2, 3],
        surface.triangles,
    ))
    @test base.nodes == (3, 2, 1)
    @test all(
        triangle_winds_outward(nodes, triangle, [1, 3, 2, 4])
        for triangle in surface.triangles
    )
end

@testset "quadratic tetrahedron ignores midside nodes" begin
    nodes = Dict(index => [0.0, 0.0, 0.0] for index in 1:10)
    nodes[1] = [0.0, 0.0, 0.0]
    nodes[2] = [1.0, 0.0, 0.0]
    nodes[3] = [0.0, 1.0, 0.0]
    nodes[4] = [0.0, 0.0, 1.0]
    for index in 5:10
        nodes[index] = [100.0, 100.0, 100.0]
    end
    mesh = Dict(
        "nodes" => nodes,
        "elements" => Dict(1 => collect(1:10)),
        "element_types" => Dict(1 => :Tet10),
    )
    surface = boundary_surface(mesh)
    @test [triangle.nodes for triangle in surface.triangles] == [
        (1, 3, 2),
        (1, 2, 4),
        (1, 4, 3),
        (2, 3, 4),
    ]
    @test surface.linearized_topologies == ["Tet10"]
    @test all(node <= 4 for triangle in surface.triangles for node in triangle.nodes)
end

@testset "shared volume face is removed and non-manifold face is counted" begin
    nodes = Dict(
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [0.0, 1.0, 0.0],
        4 => [0.0, 0.0, 1.0],
        5 => [0.0, 0.0, -1.0],
        6 => [0.2, 0.2, 2.0],
    )
    shared = Dict(
        "nodes" => nodes,
        "elements" => Dict(
            1 => [1, 2, 3, 4],
            2 => [1, 3, 2, 5],
        ),
        "element_types" => Dict(1 => :Tet4, 2 => :Tet4),
    )
    shared_surface = boundary_surface(shared)
    @test length(shared_surface.triangles) == 6
    @test shared_surface.volume_boundary_face_count == 6
    @test shared_surface.nonmanifold_face_count == 0
    @test count(triangle -> triangle.element_id == 1, shared_surface.triangles) == 3
    @test count(triangle -> triangle.element_id == 2, shared_surface.triangles) == 3
    @test !any(
        triangle -> sort(collect(triangle.nodes)) == [1, 2, 3],
        shared_surface.triangles,
    )

    nonmanifold = Dict(
        "nodes" => nodes,
        "elements" => Dict(
            1 => [1, 2, 3, 4],
            2 => [1, 3, 2, 5],
            3 => [1, 2, 3, 6],
        ),
        "element_types" => Dict(1 => :Tet4, 2 => :Tet4, 3 => :Tet4),
    )
    nonmanifold_surface = boundary_surface(nonmanifold)
    @test length(nonmanifold_surface.triangles) == 9
    @test nonmanifold_surface.volume_boundary_face_count == 9
    @test nonmanifold_surface.nonmanifold_face_count == 1
    @test !any(
        triangle -> sort(collect(triangle.nodes)) == [1, 2, 3],
        nonmanifold_surface.triangles,
    )
end

@testset "two bricks drop the shared quadrilateral" begin
    nodes = Dict(
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [1.0, 1.0, 0.0],
        4 => [0.0, 1.0, 0.0],
        5 => [0.0, 0.0, 1.0],
        6 => [1.0, 0.0, 1.0],
        7 => [1.0, 1.0, 1.0],
        8 => [0.0, 1.0, 1.0],
        9 => [0.0, 0.0, 2.0],
        10 => [1.0, 0.0, 2.0],
        11 => [1.0, 1.0, 2.0],
        12 => [0.0, 1.0, 2.0],
    )
    elements = Dict(
        1 => [1, 2, 3, 4, 5, 6, 7, 8],
        2 => [5, 6, 7, 8, 9, 10, 11, 12],
    )
    mesh = Dict(
        "nodes" => nodes,
        "elements" => elements,
        "element_types" => Dict(1 => :Hex8, 2 => :Hex8),
    )
    surface = boundary_surface(mesh)
    @test surface.volume_boundary_face_count == 10
    @test length(surface.triangles) == 20
    @test surface.nonmanifold_face_count == 0
    @test !any(
        triangle -> all(node in (5, 6, 7, 8) for node in triangle.nodes),
        surface.triangles,
    )
    @test all(
        triangle_winds_outward(nodes, triangle, elements[triangle.element_id])
        for triangle in surface.triangles
    )
end

@testset "shell faces stay in corner order and are not matched" begin
    nodes = Dict(
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [1.0, 1.0, 0.0],
        4 => [0.0, 1.0, 0.0],
    )
    mesh = Dict(
        "nodes" => nodes,
        "elements" => Dict(1 => [1, 2, 3, 4], 2 => [1, 2, 3, 4]),
        "element_types" => Dict(1 => :Quad4, 2 => :Quad4),
    )
    surface = boundary_surface(mesh)
    @test [(triangle.nodes, triangle.element_id) for triangle in surface.triangles] == [
        ((1, 2, 3), 1),
        ((1, 3, 4), 1),
        ((1, 2, 3), 2),
        ((1, 3, 4), 2),
    ]
    @test surface.volume_boundary_face_count == 0
    @test surface.surface_element_face_count == 2
    @test surface.nonmanifold_face_count == 0
end

@testset "degenerate quadrilateral uses the other diagonal" begin
    flat_primary = Dict(
        "nodes" => Dict(
            1 => [0.0, 0.0, 0.0],
            2 => [1.0, 0.0, 0.0],
            3 => [2.0, 0.0, 0.0],
            4 => [1.0, 1.0, 0.0],
        ),
        "elements" => Dict(1 => [1, 2, 3, 4]),
        "element_types" => Dict(1 => :Quad4),
    )
    surface = boundary_surface(flat_primary)
    @test [triangle.nodes for triangle in surface.triangles] == [
        (1, 2, 4),
        (2, 3, 4),
    ]

    flat = Dict(
        "nodes" => Dict(
            1 => [0.0, 0.0, 0.0],
            2 => [1.0, 0.0, 0.0],
            3 => [2.0, 0.0, 0.0],
            4 => [3.0, 0.0, 0.0],
        ),
        "elements" => Dict(1 => [1, 2, 3, 4]),
        "element_types" => Dict(1 => :Quad4),
    )
    collapsed = boundary_surface(flat)
    @test [triangle.nodes for triangle in collapsed.triangles] == [
        (1, 2, 3),
        (1, 3, 4),
    ]
end

@testset "quad9 and mixed omissions" begin
    nodes = Dict(index => [Float64(index), 0.0, 0.0] for index in 1:30)
    nodes[1] = [0.0, 0.0, 0.0]
    nodes[2] = [1.0, 0.0, 0.0]
    nodes[3] = [0.0, 1.0, 0.0]
    nodes[4] = [0.0, 0.0, 1.0]
    nodes[10] = [3.0, 0.0, 0.0]
    nodes[11] = [4.0, 0.0, 0.0]
    nodes[12] = [4.0, 1.0, 0.0]
    nodes[13] = [3.0, 1.0, 0.0]
    mesh = Dict(
        "nodes" => nodes,
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
    surface = boundary_surface(mesh)
    @test surface.volume_boundary_face_count == 4
    @test surface.surface_element_face_count == 2
    @test surface.skipped_topologies == Dict("Seg2" => 1, "Poi1" => 1)
    @test surface.unsupported_topologies == Dict("missing" => 1, "NotAnElement" => 1)
    @test surface.linearized_topologies == ["Quad9"]
    @test length(surface.triangles) == 7
    quad_triangles = filter(triangle -> triangle.element_id == 2, surface.triangles)
    @test [triangle.nodes for triangle in quad_triangles] == [
        (10, 11, 12),
        (10, 12, 13),
    ]
    @test surface.triangles[end].topology === :Tri3
    @test surface.triangles[end].element_id == 8
end

@testset "parsed deck matches the corner-node surface" begin
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
    surface = boundary_surface(mesh)
    @test length(surface.triangles) == 6
    @test surface.volume_boundary_face_count == 6
    @test surface.skipped_topologies == Dict("Seg2" => 1)
    @test surface.linearized_topologies == String[]
end

@testset "missing nodes and short connectivity" begin
    missing = Dict(
        "nodes" => Dict(
            1 => [0.0, 0.0, 0.0],
            2 => [1.0, 0.0, 0.0],
            3 => [0.0, 1.0, 0.0],
        ),
        "elements" => Dict(1 => [1, 2, 3, 4]),
        "element_types" => Dict(1 => :Tet4),
    )
    @test_throws ArgumentError("element references missing node 4") boundary_surface(missing)

    short_volume = Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0], 2 => [1.0, 0.0, 0.0], 3 => [0.0, 1.0, 0.0]),
        "elements" => Dict(1 => [1, 2, 3]),
        "element_types" => Dict(1 => :Tet4),
    )
    @test_throws ArgumentError("element 1 has too few nodes for Tet4") boundary_surface(short_volume)

    short_shell = Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0], 2 => [1.0, 0.0, 0.0], 3 => [0.0, 1.0, 0.0]),
        "elements" => Dict(1 => [1, 2, 3]),
        "element_types" => Dict(1 => :Quad4),
    )
    @test_throws ArgumentError("element 1 has too few nodes for its topology") boundary_surface(short_shell)

    empty = boundary_surface(Dict(
        "nodes" => Dict{Int,Vector{Float64}}(),
        "elements" => Dict{Int,Vector{Int}}(),
        "element_types" => Dict{Int,Symbol}(),
    ))
    @test isempty(empty.triangles)
    @test empty.nonmanifold_face_count == 0
end
