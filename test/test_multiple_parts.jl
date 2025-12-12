# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader
using Test

@testset "Multiple parts mesh - PART/ASSEMBLY structure" begin
    # Minimal example of ABAQUS structured format with multiple parts
    inp_content = """
    *HEADING
    Model with multiple parts
    *PART,NAME=PART1
    *NODE
    1, 0.0, 0.0, 0.0
    2, 1.0, 0.0, 0.0
    3, 1.0, 1.0, 0.0
    4, 0.0, 1.0, 0.0
    *ELEMENT,TYPE=CPS4,ELSET=EPART1
    1, 1, 2, 3, 4
    *SURFACE,TYPE=ELEMENT,NAME=LOADP1
    1, S1
    *END PART
    *PART,NAME=PART2
    *NODE
    1, 2.0, 0.0, 0.0
    2, 3.0, 0.0, 0.0
    3, 3.0, 1.0, 0.0
    4, 2.0, 1.0, 0.0
    *ELEMENT,TYPE=CPS4,ELSET=EPART2
    1, 1, 2, 3, 4
    *SURFACE,TYPE=ELEMENT,NAME=LOADP2
    1, S1
    *END PART
    *ASSEMBLY,NAME=ASSEMBLY1
    *INSTANCE,NAME=INST1,PART=PART1
    *END INSTANCE
    *INSTANCE,NAME=INST2,PART=PART2
    1.0, 0.0, 0.0
    *END INSTANCE
    *END ASSEMBLY
    """

    # Parse with new assembly parser
    mesh = abaqus_parse_mesh(inp_content)

    # Check that we have the parts stored separately
    @test haskey(mesh, "parts")
    @test haskey(mesh["parts"], "PART1")
    @test haskey(mesh["parts"], "PART2")

    # Check PART1 data
    @test length(mesh["parts"]["PART1"]["nodes"]) == 4
    @test length(mesh["parts"]["PART1"]["elements"]) == 1
    @test haskey(mesh["parts"]["PART1"]["element_sets"], "EPART1")

    # Check PART2 data
    @test length(mesh["parts"]["PART2"]["nodes"]) == 4
    @test length(mesh["parts"]["PART2"]["elements"]) == 1
    @test haskey(mesh["parts"]["PART2"]["element_sets"], "EPART2")

    # Check flattened mesh (backward compatibility)
    @test haskey(mesh, "nodes")
    @test haskey(mesh, "elements")
    @test length(mesh["nodes"]) == 8  # 4 from each part
    @test length(mesh["elements"]) == 2  # 1 from each part

    # Check that element sets are prefixed with part name
    @test haskey(mesh["element_sets"], "PART1.EPART1")
    @test haskey(mesh["element_sets"], "PART2.EPART2")

    # Check that surface sets are preserved and prefixed with part name
    @test haskey(mesh["surface_sets"], "PART1.LOADP1")
    @test haskey(mesh["surface_sets"], "PART2.LOADP2")
    @test mesh["surface_sets"]["PART1.LOADP1"] == [(1, :S1)]
    @test mesh["surface_sets"]["PART2.LOADP2"] == [(2, :S1)]  # element offset applied
    @test mesh["surface_types"]["PART1.LOADP1"] == :ELEMENT
    @test mesh["surface_types"]["PART2.LOADP2"] == :ELEMENT

    println("✓ PART/ASSEMBLY format mesh parsing works correctly")
end

@testset "Flat format works (for comparison)" begin
    # Traditional flat format without PART/ASSEMBLY (this should work)
    inp_content = """
    *HEADING
    Flat format model
    *NODE
    1, 0.0, 0.0, 0.0
    2, 1.0, 0.0, 0.0
    3, 1.0, 1.0, 0.0
    4, 0.0, 1.0, 0.0
    5, 2.0, 0.0, 0.0
    6, 3.0, 0.0, 0.0
    7, 3.0, 1.0, 0.0
    8, 2.0, 1.0, 0.0
    *ELEMENT,TYPE=CPS4,ELSET=PART1
    1, 1, 2, 3, 4
    *ELEMENT,TYPE=CPS4,ELSET=PART2
    2, 5, 6, 7, 8
    """

    # Mesh parsing should work
    mesh = abaqus_parse_mesh(inp_content)
    @test haskey(mesh, "nodes")
    @test haskey(mesh, "elements")
    @test length(mesh["nodes"]) == 8
    @test length(mesh["elements"]) == 2
    @test haskey(mesh["element_sets"], "PART1")
    @test haskey(mesh["element_sets"], "PART2")

    println("✓ Flat format mesh parsing works correctly")
end
