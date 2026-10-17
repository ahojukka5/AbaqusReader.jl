using Test
using AbaqusReader

@testset "minimal DC3D6 wedge write and read round-trip" begin
    # Six-node linear triangular prism (wedge) with known geometry and orientation
    # Bottom face: (0,0,0), (1,0,0), (0,1,0)
    # Top face:    (0,0,1), (1,0,1), (0,1,1)
    nodes = Dict{Int,Vector{Float64}}(
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [0.0, 1.0, 0.0],
        4 => [0.0, 0.0, 1.0],
        5 => [1.0, 0.0, 1.0],
        6 => [0.0, 1.0, 1.0],
    )
    elements = Dict{Int,Vector{Int}}(
        1 => [1, 2, 3, 4, 5, 6],
    )
    element_codes = Dict{Int,Symbol}(
        1 => :DC3D6,
    )
    element_types = Dict{Int,Symbol}(
        1 => :Wedge6,
    )
    node_sets = Dict{String,Vector{Int}}(
        "BOTTOM_NODES" => [1, 2, 3],
        "TOP_NODES"    => [4, 5, 6],
        "ALL_NODES"    => [1, 2, 3, 4, 5, 6],
    )
    element_sets = Dict{String,Vector{Int}}(
        "SHELL_1" => [1],
    )
    surface_sets = Dict{String,Vector{Tuple{Int,Symbol}}}(
        "INNER" => [(1, :S1)],
        "OUTER" => [(1, :S2)],
    )
    surface_types = Dict{String,Symbol}(
        "INNER" => :ELEMENT,
        "OUTER" => :ELEMENT,
    )

    mesh = Dict{String,Any}(
        "nodes" => nodes,
        "elements" => elements,
        "element_codes" => element_codes,
        "element_types" => element_types,
        "node_sets" => node_sets,
        "element_sets" => element_sets,
        "surface_sets" => surface_sets,
        "surface_types" => surface_types,
    )

    inp_str = abaqus_mesh_string(mesh)
    @test contains(inp_str, "*NODE")
    @test contains(inp_str, "*ELEMENT, TYPE=DC3D6")
    @test contains(inp_str, "*NSET, NSET=ALL_NODES")
    @test contains(inp_str, "*NSET, NSET=BOTTOM_NODES")
    @test contains(inp_str, "*NSET, NSET=TOP_NODES")
    @test contains(inp_str, "*ELSET, ELSET=SHELL_1")
    @test contains(inp_str, "*SURFACE, TYPE=ELEMENT, NAME=INNER")
    @test contains(inp_str, "*SURFACE, TYPE=ELEMENT, NAME=OUTER")
    @test contains(inp_str, "1, S1")
    @test contains(inp_str, "1, S2")

    # Round-trip parse through abaqus_parse_mesh
    parsed = abaqus_parse_mesh(inp_str; verbose=false)

    # Check node coordinates round-trip with exact binary64 precision
    @test length(parsed["nodes"]) == 6
    for (nid, coords) in nodes
        @test parsed["nodes"][nid] == coords
    end

    # Check element connectivity, codes, and types
    @test length(parsed["elements"]) == 1
    @test parsed["elements"][1] == [1, 2, 3, 4, 5, 6]
    @test parsed["element_codes"][1] === :DC3D6
    @test parsed["element_types"][1] === :Wedge6

    # Check sets
    @test parsed["node_sets"]["BOTTOM_NODES"] == [1, 2, 3]
    @test parsed["node_sets"]["TOP_NODES"] == [4, 5, 6]
    @test parsed["node_sets"]["ALL_NODES"] == [1, 2, 3, 4, 5, 6]
    @test parsed["element_sets"]["SHELL_1"] == [1]

    # Check surfaces
    @test parsed["surface_sets"]["INNER"] == [(1, :S1)]
    @test parsed["surface_sets"]["OUTER"] == [(1, :S2)]
    @test parsed["surface_types"]["INNER"] === :ELEMENT
    @test parsed["surface_types"]["OUTER"] === :ELEMENT
end

@testset "wedge face ordering and orientation against Abaqus reference" begin
    # Reference orientation check for 6-node linear wedge (C3D6 / DC3D6):
    # Bottom triangular face: nodes 1, 2, 3 (counter-clockwise looking from outside/below)
    # Top triangular face:    nodes 4, 5, 6 (4 above 1, 5 above 2, 6 above 3)
    p1 = [0.0, 0.0, 0.0]
    p2 = [2.0, 0.0, 0.0]
    p3 = [0.0, 2.0, 0.0]
    p4 = [0.0, 0.0, 3.0]
    p5 = [2.0, 0.0, 3.0]
    p6 = [0.0, 2.0, 3.0]

    # 1. Orientation test: Jacobian determinant / prism volume is positive
    # (v2 - v1) x (v3 - v1) . (v4 - v1) = [2, 0, 0] x [0, 2, 0] . [0, 0, 3] = [0, 0, 4] . [0, 0, 3] = 12 > 0
    cross_prod = [
        (p2[2]-p1[2])*(p3[3]-p1[3]) - (p2[3]-p1[3])*(p3[2]-p1[2]),
        (p2[3]-p1[3])*(p3[1]-p1[1]) - (p2[1]-p1[1])*(p3[3]-p1[3]),
        (p2[1]-p1[1])*(p3[2]-p1[2]) - (p2[2]-p1[2])*(p3[1]-p1[1]),
    ]
    det_J = cross_prod[1]*(p4[1]-p1[1]) + cross_prod[2]*(p4[2]-p1[2]) + cross_prod[3]*(p4[3]-p1[3])
    @test det_J > 0.0

    # 2. Abaqus Standard User's Guide (Solid Element Library -> C3D6 / DC3D6):
    # Face 1 (S1): 1 - 2 - 3 (bottom face, outward normal in -Z)
    # Face 2 (S2): 4 - 6 - 5 (top face, outward normal in +Z)
    # Face 3 (S3): 1 - 4 - 5 - 2 (side face at y=0, outward normal in -Y)
    # Face 4 (S4): 2 - 5 - 6 - 3 (slanted hypotenuse side, outward normal in +X+Y)
    # Face 5 (S5): 3 - 6 - 4 - 1 (side face at x=0, outward normal in -X)

    # Face 1 outward normal: (p3 - p1) x (p2 - p1) points in -Z:
    n_face1 = [
        (p3[2]-p1[2])*(p2[3]-p1[3]) - (p3[3]-p1[3])*(p2[2]-p1[2]),
        (p3[3]-p1[3])*(p2[1]-p1[1]) - (p3[1]-p1[1])*(p2[3]-p1[3]),
        (p3[1]-p1[1])*(p2[2]-p1[2]) - (p3[2]-p1[2])*(p2[1]-p1[1]),
    ]
    @test n_face1[1] == 0.0 && n_face1[2] == 0.0 && n_face1[3] < 0.0

    # Face 2 outward normal (4-5-6): (p5 - p4) x (p6 - p4) points in +Z:
    n_face2 = [
        (p5[2]-p4[2])*(p6[3]-p4[3]) - (p5[3]-p4[3])*(p6[2]-p4[2]),
        (p5[3]-p4[3])*(p6[1]-p4[1]) - (p5[1]-p4[1])*(p6[3]-p4[3]),
        (p5[1]-p4[1])*(p6[2]-p4[2]) - (p5[2]-p4[2])*(p6[1]-p4[1]),
    ]
    @test n_face2[1] == 0.0 && n_face2[2] == 0.0 && n_face2[3] > 0.0

    # Build mesh with all 5 faces defined as surfaces
    wedge_mesh = Dict(
        "nodes" => Dict(1=>p1, 2=>p2, 3=>p3, 4=>p4, 5=>p5, 6=>p6),
        "elements" => Dict(10 => [1, 2, 3, 4, 5, 6]),
        "element_codes" => Dict(10 => :DC3D6),
        "surface_sets" => Dict(
            "BOTTOM" => [(10, :S1)],
            "TOP"    => [(10, :S2)],
            "SIDE_Y" => [(10, :S3)],
            "SIDE_HYP" => [(10, :S4)],
            "SIDE_X" => [(10, :S5)],
        )
    )

    deck = abaqus_mesh_string(wedge_mesh)
    # Check that each face keyword is emitted cleanly
    @test contains(deck, "*SURFACE, TYPE=ELEMENT, NAME=BOTTOM\n10, S1")
    @test contains(deck, "*SURFACE, TYPE=ELEMENT, NAME=TOP\n10, S2")
    @test contains(deck, "*SURFACE, TYPE=ELEMENT, NAME=SIDE_Y\n10, S3")
    @test contains(deck, "*SURFACE, TYPE=ELEMENT, NAME=SIDE_HYP\n10, S4")
    @test contains(deck, "*SURFACE, TYPE=ELEMENT, NAME=SIDE_X\n10, S5")

    # Round-trip verify
    parsed = abaqus_parse_mesh(deck; verbose=false)
    for (sname, expected_pair) in wedge_mesh["surface_sets"]
        @test parsed["surface_sets"][sname] == expected_pair
    end
end

@testset "disconnected 2-body fixtures with coincident non-welded nodes" begin
    # Fixture C1: Two adjacent wedge bodies that share an interface with identical
    # coincident coordinates, but have distinct node IDs (nodes 4,5,6 of body 1
    # coincide with nodes 7,8,9 of body 2). Writer must NOT weld or renumber them.
    nodes = Dict{Int,Vector{Float64}}(
        # Body 1: z from 0 to 1
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [0.0, 1.0, 0.0],
        4 => [0.0, 0.0, 1.0],
        5 => [1.0, 0.0, 1.0],
        6 => [0.0, 1.0, 1.0],
        # Body 2: z from 1 to 2 (coincident interface at z=1.0)
        7  => [0.0, 0.0, 1.0],
        8  => [1.0, 0.0, 1.0],
        9  => [0.0, 1.0, 1.0],
        10 => [0.0, 0.0, 2.0],
        11 => [1.0, 0.0, 2.0],
        12 => [0.0, 1.0, 2.0],
    )
    elements = Dict{Int,Vector{Int}}(
        1 => [1, 2, 3, 4, 5, 6],
        2 => [7, 8, 9, 10, 11, 12],
    )
    node_sets = Dict{String,Vector{Int}}(
        "BODY1_NODES" => collect(1:6),
        "BODY2_NODES" => collect(7:12),
    )
    element_sets = Dict{String,Vector{Int}}(
        "SHELL_INNER" => [1],
        "SHELL_OUTER" => [2],
    )
    surface_sets = Dict{String,Vector{Tuple{Int,Symbol}}}(
        "INTERFACE_MINUS" => [(1, :S2)],
        "INTERFACE_PLUS"  => [(2, :S1)],
    )

    mesh = Dict(
        "nodes" => nodes,
        "elements" => elements,
        "node_sets" => node_sets,
        "element_sets" => element_sets,
        "surface_sets" => surface_sets,
    )

    # Use element_code argument to set all elements to DC3D6
    inp_str = abaqus_mesh_string(mesh; element_code=:DC3D6)
    parsed = abaqus_parse_mesh(inp_str; verbose=false)

    # Verify no welding: all 12 nodes remain distinct with original IDs
    @test length(parsed["nodes"]) == 12
    for nid in 1:12
        @test haskey(parsed["nodes"], nid)
        @test parsed["nodes"][nid] == nodes[nid]
    end

    # Verify connectivity preserved exactly
    @test parsed["elements"][1] == [1, 2, 3, 4, 5, 6]
    @test parsed["elements"][2] == [7, 8, 9, 10, 11, 12]

    # Verify sets
    @test parsed["node_sets"]["BODY1_NODES"] == collect(1:6)
    @test parsed["node_sets"]["BODY2_NODES"] == collect(7:12)
    @test parsed["element_sets"]["SHELL_INNER"] == [1]
    @test parsed["element_sets"]["SHELL_OUTER"] == [2]

    # Verify interface surfaces
    @test parsed["surface_sets"]["INTERFACE_MINUS"] == [(1, :S2)]
    @test parsed["surface_sets"]["INTERFACE_PLUS"]  == [(2, :S1)]
end

@testset "rotated nonmatching 2-body fixture" begin
    # Fixture C2: Body 2 is rotated by 45 degrees around Z axis
    theta = π / 4
    c, s = cos(theta), sin(theta)
    rot(x, y, z) = [c*x - s*y, s*x + c*y, z]

    nodes = Dict{Int,Vector{Float64}}(
        # Body 1
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [0.0, 1.0, 0.0],
        4 => [0.0, 0.0, 1.0],
        5 => [1.0, 0.0, 1.0],
        6 => [0.0, 1.0, 1.0],
        # Body 2 (rotated)
        101 => rot(0.0, 0.0, 1.0),
        102 => rot(1.0, 0.0, 1.0),
        103 => rot(0.0, 1.0, 1.0),
        104 => rot(0.0, 0.0, 2.0),
        105 => rot(1.0, 0.0, 2.0),
        106 => rot(0.0, 1.0, 2.0),
    )
    elements = Dict{Int,Vector{Int}}(
        1 => [1, 2, 3, 4, 5, 6],
        2 => [101, 102, 103, 104, 105, 106],
    )

    mesh = Dict(
        "nodes" => nodes,
        "elements" => elements,
        "element_codes" => Dict(1 => :DC3D6, 2 => :DC3D6),
    )

    inp_str = abaqus_mesh_string(mesh)
    parsed = abaqus_parse_mesh(inp_str; verbose=false)

    for (nid, expected_coords) in nodes
        @test parsed["nodes"][nid] == expected_coords
    end
    @test parsed["elements"][1] == [1, 2, 3, 4, 5, 6]
    @test parsed["elements"][2] == [101, 102, 103, 104, 105, 106]
end

@testset "output is usable through *INCLUDE" begin
    mktempdir() do tmpdir
        mesh_path = joinpath(tmpdir, "spherical_shell_mesh.inp")
        parent_path = joinpath(tmpdir, "analysis_deck.inp")

        mesh = Dict(
            "nodes" => Dict(
                10 => [0.0, 0.0, 0.0],
                20 => [1.0, 0.0, 0.0],
                30 => [0.0, 1.0, 0.0],
                40 => [0.0, 0.0, 1.0],
                50 => [1.0, 0.0, 1.0],
                60 => [0.0, 1.0, 1.0],
            ),
            "elements" => Dict(100 => [10, 20, 30, 40, 50, 60]),
            "element_codes" => Dict(100 => :DC3D6),
            "node_sets" => Dict("INNER_NODES" => [10, 20, 30]),
            "element_sets" => Dict("LAYER_1" => [100]),
            "surface_sets" => Dict("SHELL_SURF" => [(100, :S1)]),
        )

        abaqus_write_mesh(mesh_path, mesh)
        @test isfile(mesh_path)

        # Parent deck that includes the mesh file
        parent_deck = """
        *HEADING
        Nine-shell nonconforming spherical benchmark (MortarLab #262)
        ** Include the separate mesh file
        *INCLUDE, INPUT=spherical_shell_mesh.inp
        *MATERIAL, NAME=STEEL
        *CONDUCTIVITY
        50.0
        *SOLID SECTION, ELSET=LAYER_1, MATERIAL=STEEL
        *STEP
        *HEAT TRANSFER, STEADY STATE
        *END STEP
        """
        write(parent_path, parent_deck)

        # Read through abaqus_read_mesh, which expands *INCLUDE
        expanded_mesh = abaqus_read_mesh(parent_path; verbose=false)

        @test length(expanded_mesh["nodes"]) == 6
        @test expanded_mesh["nodes"][10] == [0.0, 0.0, 0.0]
        @test expanded_mesh["elements"][100] == [10, 20, 30, 40, 50, 60]
        @test expanded_mesh["element_codes"][100] === :DC3D6
        @test expanded_mesh["element_types"][100] === :Wedge6
        @test expanded_mesh["node_sets"]["INNER_NODES"] == [10, 20, 30]
        @test expanded_mesh["element_sets"]["LAYER_1"] == [100]
        @test expanded_mesh["surface_sets"]["SHELL_SURF"] == [(100, :S1)]
        @test expanded_mesh["surface_types"]["SHELL_SURF"] === :ELEMENT
    end
end

@testset "deterministic serialization" begin
    # Test that dictionary insertion order does not affect the output string
    nodes_order1 = Dict{Int,Vector{Float64}}(
        3 => [0.0, 1.0, 0.0],
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        6 => [0.0, 1.0, 1.0],
        4 => [0.0, 0.0, 1.0],
        5 => [1.0, 0.0, 1.0],
    )
    nodes_order2 = Dict{Int,Vector{Float64}}(
        1 => [0.0, 0.0, 0.0],
        5 => [1.0, 0.0, 1.0],
        2 => [1.0, 0.0, 0.0],
        4 => [0.0, 0.0, 1.0],
        6 => [0.0, 1.0, 1.0],
        3 => [0.0, 1.0, 0.0],
    )

    nsets_order1 = Dict("Z_SET" => [5, 4], "A_SET" => [2, 1])
    nsets_order2 = Dict("A_SET" => [1, 2], "Z_SET" => [4, 5])

    surfs_order1 = Dict("SURF_B" => [(1, :S2), (1, :S1)], "SURF_A" => [(1, :S1)])
    surfs_order2 = Dict("SURF_A" => [(1, :S1)], "SURF_B" => [(1, :S1), (1, :S2)])

    mesh1 = Dict(
        "nodes" => nodes_order1,
        "elements" => Dict(1 => [1, 2, 3, 4, 5, 6]),
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => nsets_order1,
        "surface_sets" => surfs_order1,
    )
    mesh2 = Dict(
        "nodes" => nodes_order2,
        "elements" => Dict(1 => [1, 2, 3, 4, 5, 6]),
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => nsets_order2,
        "surface_sets" => surfs_order2,
    )

    str1 = abaqus_mesh_string(mesh1)
    str2 = abaqus_mesh_string(mesh2)

    @test str1 == str2
end

@testset "mixed element codes and long line wrapping" begin
    # Mesh with mixed element codes: C3D8 (Hex8) and DC3D6 (Wedge6)
    nodes = Dict(
        1 => [0.0, 0.0, 0.0], 2 => [1.0, 0.0, 0.0], 3 => [1.0, 1.0, 0.0], 4 => [0.0, 1.0, 0.0],
        5 => [0.0, 0.0, 1.0], 6 => [1.0, 0.0, 1.0], 7 => [1.0, 1.0, 1.0], 8 => [0.0, 1.0, 1.0],
        9 => [2.0, 0.0, 0.0], 10 => [2.0, 0.0, 1.0],
    )
    # Hex element (1..8) and Wedge element (2, 9, 3, 6, 10, 7)
    elements = Dict(
        1 => [1, 2, 3, 4, 5, 6, 7, 8],
        2 => [2, 9, 3, 6, 10, 7],
    )
    mesh = Dict(
        "nodes" => nodes,
        "elements" => elements,
        "element_codes" => Dict(1 => :C3D8, 2 => :DC3D6),
    )

    str = abaqus_mesh_string(mesh)
    @test contains(str, "*ELEMENT, TYPE=C3D8\n1, 1, 2, 3, 4, 5, 6, 7, 8")
    @test contains(str, "*ELEMENT, TYPE=DC3D6\n2, 2, 9, 3, 6, 10, 7")

    parsed = abaqus_parse_mesh(str; verbose=false)
    @test parsed["element_codes"][1] === :C3D8
    @test parsed["element_types"][1] === :Hex8
    @test parsed["element_codes"][2] === :DC3D6
    @test parsed["element_types"][2] === :Wedge6

    # Test set line wrapping with > 16 members
    large_nset = Dict("LARGE" => collect(1:35))
    nodes_large = Dict(i => [Float64(i), 0.0, 0.0] for i in 1:35)
    elem_large = Dict(1 => collect(1:8))
    mesh_large = Dict(
        "nodes" => nodes_large,
        "elements" => elem_large,
        "element_codes" => Dict(1 => :C3D8),
        "node_sets" => large_nset,
    )
    large_str = abaqus_mesh_string(mesh_large)
    parsed_large = abaqus_parse_mesh(large_str; verbose=false)
    @test parsed_large["node_sets"]["LARGE"] == collect(1:35)
end

@testset "validation and negative tests" begin
    valid_nodes = Dict(
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [0.0, 1.0, 0.0],
        4 => [0.0, 0.0, 1.0],
        5 => [1.0, 0.0, 1.0],
        6 => [0.0, 1.0, 1.0],
    )
    valid_elems = Dict(1 => [1, 2, 3, 4, 5, 6])

    # 1. Empty nodes
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict{Int,Vector{Float64}}(),
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
    ))

    # 2. Empty elements
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => Dict{Int,Vector{Int}}(),
        "element_codes" => Dict{Int,Symbol}(),
    ))

    # 3. Non-positive or non-integer node ID
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(0 => [0.0, 0.0, 0.0]),
        "elements" => Dict(1 => [0]),
        "element_codes" => Dict(1 => :DC3D6),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict("not_an_id" => [0.0, 0.0, 0.0]),
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
    ))

    # 4. Non-finite coordinate (NaN, Inf) — use MASS (Poi1 topology, 1 node) to avoid
    #    a node-count mismatch obscuring the real error under test
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1 => [NaN, 0.0, 0.0]),
        "elements" => Dict(1 => [1]),
        "element_codes" => Dict(1 => :MASS),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1 => [Inf, 0.0, 0.0]),
        "elements" => Dict(1 => [1]),
        "element_codes" => Dict(1 => :MASS),
    ))

    # 5. Missing node reference in element
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => Dict(1 => [1, 2, 3, 4, 5, 999]),
        "element_codes" => Dict(1 => :DC3D6),
    ))

    # 6. Missing element code when none specified
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
    ))

    # 7. Unknown element code
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :NONEXISTENT_ELEM),
    ))

    # 8. Node count arity mismatch for element code (DC3D6 expects 6 nodes, got 4)
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => Dict(1 => [1, 2, 3, 4]),
        "element_codes" => Dict(1 => :DC3D6),
    ))

    # 9. Element code topology mismatch with element_types
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "element_types" => Dict(1 => :Hex8),
    ))

    # 10. Wedge18 rejection
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(i => [Float64(i), 0.0, 0.0] for i in 1:18),
        "elements" => Dict(1 => collect(1:18)),
        "element_codes" => Dict(1 => :C3D15),
        "element_types" => Dict(1 => :Wedge18),
    ))

    # 11. Missing node reference in node set
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("BAD_SET" => [1, 2, 999]),
    ))

    # 12. Missing element reference in element set
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "element_sets" => Dict("BAD_ELSET" => [1, 999]),
    ))

    # 13. Missing element reference in surface
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("BAD_SURF" => [(999, :S1)]),
    ))

    # 14. Unknown surface face for topology (e.g. S6 for a 5-faced Wedge6)
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("BAD_FACE" => [(1, :S6)]),
    ))

    # 15. Unsupported surface type (non-ELEMENT)
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("SURF" => [(1, :S1)]),
        "surface_types" => Dict("SURF" => :NODE),
    ))

    # 16. Node ID exceeds Abaqus maximum (999_999_999)
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1_000_000_000 => [0.0, 0.0, 0.0]),
        "elements" => Dict(1 => [1]),
        "element_codes" => Dict(1 => :MASS),
    ))

    # 17. Element ID exceeds Abaqus maximum (999_999_999)
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0]),
        "elements" => Dict(1_000_000_000 => [1]),
        "element_codes" => Dict(1_000_000_000 => :MASS),
    ))

    # 18. Invalid set name: begins with digit
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("1BAD" => [1]),
    ))

    # 19. Invalid set name: contains comma (injection risk)
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("INNER,TYPE=NODE" => [1]),
    ))

    # 20. Invalid set name: contains newline (injection risk)
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("A\n*STEP" => [1]),
    ))

    # 21. Invalid set name: contains period (reserved in Abaqus part-instance notation)
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("Set.1" => [1]),
    ))

    # 22. Case-insensitive duplicate node set names
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("MySet" => [1], "MYSET" => [2]),
    ))

    # 23. Case-insensitive duplicate element set names
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "element_sets" => Dict("MyElset" => [1], "MYELSET" => [1]),
    ))

    # 24. Case-insensitive duplicate surface names
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("MySurf" => [(1, :S1)], "MYSURF" => [(1, :S2)]),
    ))

    # 25. Topology with no element-based face contract fails closed
    #     MASS is an element with topology Poi1, which has no VALID_TOPOLOGY_FACES entry
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0]),
        "elements" => Dict(1 => [1]),
        "element_codes" => Dict(1 => :MASS),
        "surface_sets" => Dict("SURF" => [(1, :S1)]),
    ))

    # 26. Mixed raw keys that normalize to the same node or element ID
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0], "1" => [1.0, 0.0, 0.0]),
        "elements" => Dict(1 => [1]),
        "element_codes" => Dict(1 => :MASS),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0]),
        "elements" => Dict(1 => [1], "1" => [1]),
        "element_codes" => Dict(1 => :MASS),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0]),
        "elements" => Dict(1 => [1]),
        "element_codes" => Dict(1 => :MASS, "1" => :DCOUP3D),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0]),
        "elements" => Dict(1 => [1]),
        "element_codes" => Dict(1 => :MASS),
        "element_types" => Dict(1 => :Poi1, "1" => :Poi1),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
    ); element_codes=Dict(1 => :DC3D6, "1" => :DC3D6))

    # 27. Node ID is neither an integer nor a numeric string
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => Dict(1.5 => [0.0, 0.0, 0.0]),
        "elements" => Dict(1 => [1]),
        "element_codes" => Dict(1 => :MASS),
    ))

    # 28. Empty, padded, or overlong unquoted names
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("" => [1]),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "element_sets" => Dict(" E_ALL" => [1]),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("S"^81 => [(1, :S1)]),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("A=B" => [1]),
    ))

    # 29. Set and surface values must be non-empty collections of pairs or IDs
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("NSET" => 1),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "element_sets" => Dict("ELSET" => 1),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("SURF" => 1),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "node_sets" => Dict("NSET" => Int[]),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "element_sets" => Dict("ELSET" => Int[]),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("SURF" => Tuple{Int,Symbol}[]),
    ))
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => valid_elems,
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("SURF" => [(1,)]),
    ))
end

@testset "20-node C3D20 continuation lines and binary64 round-trip" begin
    # C3D20 has 20 nodes which exceeds the 15-node threshold for Abaqus continuation lines.
    # The writer must emit: element_id, nodes[1:15],  (with trailing comma)
    #                        nodes[16:20]
    # and the parser must reconstruct the complete connectivity.

    # Corner nodes (1-8) are the unit cube. Midside nodes (9-20) sit on the
    # edges. Node 9 uses π/4 so one coordinate is not a short decimal.
    nodes_20 = Dict{Int,Vector{Float64}}(
        # Corner nodes
        1 => [0.0, 0.0, 0.0], 2 => [1.0, 0.0, 0.0],
        3 => [1.0, 1.0, 0.0], 4 => [0.0, 1.0, 0.0],
        5 => [0.0, 0.0, 1.0], 6 => [1.0, 0.0, 1.0],
        7 => [1.0, 1.0, 1.0], 8 => [0.0, 1.0, 1.0],
        # Node 9's x coordinate is π/4, which is not a short decimal.
        9  => [π / 4, 0.0, 0.0],
        10 => [1.0, 0.5, 0.0],
        11 => [0.5, 1.0, 0.0],
        12 => [0.0, 0.5, 0.0],
        13 => [0.5, 0.0, 1.0],
        14 => [1.0, 0.5, 1.0],
        15 => [0.5, 1.0, 1.0],
        16 => [0.0, 0.5, 1.0],
        17 => [0.0, 0.0, 0.5],
        18 => [1.0, 0.0, 0.5],
        19 => [1.0, 1.0, 0.5],
        20 => [0.0, 1.0, 0.5],
    )
    # Connectivity per Abaqus C3D20 numbering
    conn_20 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

    mesh20 = Dict(
        "nodes" => nodes_20,
        "elements" => Dict(1 => conn_20),
        "element_codes" => Dict(1 => :C3D20),
        "element_sets" => Dict("SOLID" => [1]),
    )

    deck = abaqus_mesh_string(mesh20)

    # Writer must produce an Abaqus-style continuation: first line ends with ","
    # Verify the element block splits at 15 nodes
    lines = split(deck, '\n')
    elem_header_idx = findfirst(l -> startswith(l, "*ELEMENT, TYPE=C3D20"), lines)
    @test elem_header_idx !== nothing
    first_conn_line = lines[elem_header_idx + 1]
    second_conn_line = lines[elem_header_idx + 2]

    # First line must end with "," and contain exactly 16 comma-separated tokens
    # (element_id + 15 node IDs)
    @test endswith(first_conn_line, ",")
    first_tokens = split(first_conn_line[1:end-1], ", ")
    @test length(first_tokens) == 16  # eid + 15 node IDs

    # Second line contains the remaining 5 node IDs
    second_tokens = split(strip(second_conn_line), ", ")
    @test length(second_tokens) == 5

    # The full connectivity reconstructed is exactly the original
    reconstructed = [parse(Int, t) for t in [first_tokens[2:end]; second_tokens]]
    @test reconstructed == conn_20

    # Round-trip through abaqus_parse_mesh
    parsed = abaqus_parse_mesh(deck; verbose=false)

    @test length(parsed["nodes"]) == 20
    @test parsed["elements"][1] == conn_20
    @test parsed["element_codes"][1] === :C3D20
    @test parsed["element_types"][1] === :Hex20
    @test parsed["element_sets"]["SOLID"] == [1]

    # Binary64 coordinate precision: every coordinate must round-trip exactly
    for nid in 1:20
        @test parsed["nodes"][nid] == nodes_20[nid]
    end

    # Non-trivial binary64 test: use a value that is NOT exactly representable in
    # decimal with fewer than 17 significant digits
    tricky_val = 1.0 / 3.0
    tricky_mesh = Dict(
        "nodes" => Dict(1 => [tricky_val, 0.0, 0.0]),
        "elements" => Dict(1 => [1]),
        "element_codes" => Dict(1 => :MASS),  # MASS maps to Poi1 topology (1 node)
    )
    tricky_deck = abaqus_mesh_string(tricky_mesh)
    tricky_parsed = abaqus_parse_mesh(tricky_deck; verbose=false)
    @test tricky_parsed["nodes"][1][1] === tricky_val
end

@testset "element continuation repeats after sixteen node numbers" begin
    # The element id and the first 15 nodes share a line. Later lines hold
    # at most 16 node numbers. No registered element needs a third line, so
    # this case turns validation off and checks the wrapper directly.
    conn = collect(1:33)
    mesh = Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0]),
        "elements" => Dict(1 => conn),
        "element_codes" => Dict(1 => :C3D20),
    )
    deck = abaqus_mesh_string(mesh; validate=false)
    lines = split(chomp(deck), '\n')
    header = findfirst(l -> startswith(l, "*ELEMENT, TYPE=C3D20"), lines)
    @test header !== nothing
    first = lines[header + 1]
    second = lines[header + 2]
    third = lines[header + 3]
    @test endswith(first, ",")
    @test endswith(second, ",")
    @test !endswith(third, ",")
    ids = Int[]
    for line in (first, second, third)
        body = endswith(line, ",") ? line[1:end-1] : line
        append!(ids, parse.(Int, split(body, ", ")))
    end
    @test ids[1] == 1
    @test ids[2:end] == conn
end

@testset "label bounds and unquoted names that the writer accepts" begin
    name80 = "N" * "-"^79
    @test length(name80) == 80
    mesh = Dict(
        "nodes" => Dict("999999999" => [1.0 / 3.0, 0.0, 0.0]),
        "elements" => Dict(999_999_999 => [999_999_999]),
        "element_codes" => Dict("999999999" => :MASS),
        "node_sets" => Dict(name80 => [999_999_999]),
        "element_sets" => Dict("SET-A" => [999_999_999]),
    )
    deck = abaqus_mesh_string(mesh)
    @test contains(deck, "*NSET, NSET=$name80")
    @test contains(deck, "*ELSET, ELSET=SET-A")
    parsed = abaqus_parse_mesh(deck; verbose=false)
    @test parsed["nodes"][999_999_999][1] === 1.0 / 3.0
    @test parsed["elements"][999_999_999] == [999_999_999]
    @test parsed["element_codes"][999_999_999] === :MASS
    @test parsed["node_sets"][name80] == [999_999_999]
    @test parsed["element_sets"]["SET-A"] == [999_999_999]
end

@testset "comments keyword covers both AbstractString and vector paths" begin
    mesh = Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0], 2 => [1.0, 0.0, 0.0],
                        3 => [0.0, 1.0, 0.0], 4 => [0.0, 0.0, 1.0],
                        5 => [1.0, 0.0, 1.0], 6 => [0.0, 1.0, 1.0]),
        "elements" => Dict(1 => [1, 2, 3, 4, 5, 6]),
        "element_codes" => Dict(1 => :DC3D6),
    )

    # AbstractString path: single string with embedded newline
    deck_str = abaqus_mesh_string(mesh; comments="Header line\nSecond line")
    @test contains(deck_str, "** Header line\n")
    @test contains(deck_str, "** Second line\n")

    # Vector path
    deck_vec = abaqus_mesh_string(mesh; comments=["Line A", "Line B"])
    @test contains(deck_vec, "** Line A\n")
    @test contains(deck_vec, "** Line B\n")
end

@testset "Pair format in surface_sets" begin
    # Verify that Pair{Int,Symbol} entries are accepted alongside tuples
    mesh = Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0], 2 => [1.0, 0.0, 0.0],
                        3 => [0.0, 1.0, 0.0], 4 => [0.0, 0.0, 1.0],
                        5 => [1.0, 0.0, 1.0], 6 => [0.0, 1.0, 1.0]),
        "elements" => Dict(1 => [1, 2, 3, 4, 5, 6]),
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("S" => [1 => :S1]),
    )
    deck = abaqus_mesh_string(mesh)
    @test contains(deck, "*SURFACE, TYPE=ELEMENT, NAME=S\n1, S1")
end

@testset "Symbol key lookup in mesh fields" begin
    # _get_mesh_field must fall back to Symbol keys
    mesh = Dict(
        :nodes => Dict(1 => [0.0, 0.0, 0.0], 2 => [1.0, 0.0, 0.0],
                       3 => [0.0, 1.0, 0.0], 4 => [0.0, 0.0, 1.0],
                       5 => [1.0, 0.0, 1.0], 6 => [0.0, 1.0, 1.0]),
        :elements => Dict(1 => [1, 2, 3, 4, 5, 6]),
        :element_codes => Dict(1 => :DC3D6),
    )
    deck = abaqus_mesh_string(mesh)
    @test contains(deck, "*NODE")
    @test contains(deck, "*ELEMENT, TYPE=DC3D6")
end

@testset "element_codes keyword argument path" begin
    # Exercise the element_codes *keyword argument* override (kw_element_codes path)
    mesh_no_codes = Dict(
        "nodes" => Dict(1 => [0.0, 0.0, 0.0], 2 => [1.0, 0.0, 0.0],
                        3 => [0.0, 1.0, 0.0], 4 => [0.0, 0.0, 1.0],
                        5 => [1.0, 0.0, 1.0], 6 => [0.0, 1.0, 1.0]),
        "elements" => Dict(1 => [1, 2, 3, 4, 5, 6]),
        # no "element_codes" key in the mesh dict
    )
    # Pass codes via keyword argument
    deck = abaqus_mesh_string(mesh_no_codes; element_codes=Dict(1 => :DC3D6))
    @test contains(deck, "*ELEMENT, TYPE=DC3D6")
    parsed = abaqus_parse_mesh(deck; verbose=false)
    @test parsed["element_codes"][1] === :DC3D6
    @test parsed["elements"][1] == [1, 2, 3, 4, 5, 6]
end

@testset "invalid surface entry format throws" begin
    # An integer is neither a Pair, Tuple, nor AbstractVector → hits the else branch
    valid_nodes = Dict(
        1 => [0.0, 0.0, 0.0], 2 => [1.0, 0.0, 0.0], 3 => [0.0, 1.0, 0.0],
        4 => [0.0, 0.0, 1.0], 5 => [1.0, 0.0, 1.0], 6 => [0.0, 1.0, 1.0],
    )
    @test_throws ArgumentError abaqus_mesh_string(Dict(
        "nodes" => valid_nodes,
        "elements" => Dict(1 => [1, 2, 3, 4, 5, 6]),
        "element_codes" => Dict(1 => :DC3D6),
        "surface_sets" => Dict("S" => [42]),  # 42 is an Int, not a pair
    ))
end
