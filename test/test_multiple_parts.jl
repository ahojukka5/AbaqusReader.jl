# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader
using Test

@testset "Assembly instances preserve names and translated placement" begin
    input = """
    *HEADING
    Model with translated instances
    *PART, NAME=PART1
    *NODE
    1, 0.0, 0.0, 0.0
    2, 1.0, 0.0, 0.0
    3, 1.0, 1.0, 0.0
    4, 0.0, 1.0, 0.0
    *NSET, NSET=CORNER
    1
    *ELEMENT, TYPE=CPS4, ELSET=EPART1
    1, 1, 2, 3, 4
    *SURFACE, TYPE=ELEMENT, NAME=LOADP1
    1, S1
    *END PART
    *PART, NAME=PART2
    *NODE
    1, 0.0, 0.0, 0.0
    2, 1.0, 0.0, 0.0
    3, 1.0, 1.0, 0.0
    4, 0.0, 1.0, 0.0
    *ELEMENT, TYPE=CPS4, ELSET=EPART2
    1, 1, 2, 3, 4
    *SURFACE, TYPE=ELEMENT, NAME=LOADP2
    1, S1
    *END PART
    *ASSEMBLY, NAME=ASSEMBLY1
    *INSTANCE, NAME=INST1, PART=PART1
    *END INSTANCE
    *INSTANCE, NAME=INST2, PART=PART2
    2.0, 0.0, 0.0
    *END INSTANCE
    *END ASSEMBLY
    """

    mesh = abaqus_parse_mesh(input)

    @test sort(collect(keys(mesh["parts"]))) == ["PART1", "PART2"]
    @test sort(collect(keys(mesh["assembly"]["instances"]))) ==
        ["INST1", "INST2"]
    @test mesh["instance_parts"] == Dict(
        "INST1" => "PART1",
        "INST2" => "PART2",
    )
    @test mesh["assembly"]["instances"]["INST1"]["translation"] ==
        [0.0, 0.0, 0.0]
    @test mesh["assembly"]["instances"]["INST2"]["translation"] ==
        [2.0, 0.0, 0.0]

    @test length(mesh["nodes"]) == 8
    @test length(mesh["elements"]) == 2
    @test mesh["nodes"][1] ≈ [0.0, 0.0, 0.0]
    @test mesh["nodes"][4] ≈ [0.0, 1.0, 0.0]
    @test mesh["nodes"][5] ≈ [2.0, 0.0, 0.0]
    @test mesh["nodes"][7] ≈ [3.0, 1.0, 0.0]
    @test mesh["elements"][1] == [1, 2, 3, 4]
    @test mesh["elements"][2] == [5, 6, 7, 8]
    @test mesh["element_types"] == Dict(1 => :Quad4, 2 => :Quad4)
    @test mesh["element_codes"] == Dict(1 => :CPS4, 2 => :CPS4)

    @test mesh["element_sets"]["INST1.EPART1"] == [1]
    @test mesh["element_sets"]["INST2.EPART2"] == [2]
    @test mesh["node_sets"]["INST1.CORNER"] == [1]
    @test mesh["surface_sets"]["INST1.LOADP1"] == [(1, :S1)]
    @test mesh["surface_sets"]["INST2.LOADP2"] == [(2, :S1)]
    @test mesh["surface_types"]["INST1.LOADP1"] == :ELEMENT
    @test mesh["surface_types"]["INST2.LOADP2"] == :ELEMENT
end

@testset "One part can be instantiated repeatedly" begin
    input = """
    *PART, NAME=PLATE
    *NODE
    1, 0.0, 0.0, 0.0
    2, 1.0, 0.0, 0.0
    3, 1.0, 1.0, 0.0
    4, 0.0, 1.0, 0.0
    *ELEMENT, TYPE=S4, ELSET=ALL
    1, 1, 2, 3, 4
    *SURFACE, TYPE=ELEMENT, NAME=TOP
    1, S1
    *END PART
    *ASSEMBLY, NAME=A
    *INSTANCE, NAME=LEFT, PART=PLATE
    *END INSTANCE
    *INSTANCE, NAME=RIGHT, PART=PLATE
    10.0, 0.0, 0.0
    *END INSTANCE
    *END ASSEMBLY
    """

    mesh = abaqus_parse_mesh(input)
    @test mesh["instance_parts"] == Dict(
        "LEFT" => "PLATE",
        "RIGHT" => "PLATE",
    )
    @test length(mesh["nodes"]) == 8
    @test length(mesh["elements"]) == 2
    @test mesh["nodes"][1] ≈ [0.0, 0.0, 0.0]
    @test mesh["nodes"][5] ≈ [10.0, 0.0, 0.0]
    @test mesh["element_codes"][1] == :S4
    @test mesh["element_codes"][2] == :S4
    @test mesh["element_sets"]["LEFT.ALL"] == [1]
    @test mesh["element_sets"]["RIGHT.ALL"] == [2]
    @test mesh["surface_sets"]["LEFT.TOP"] == [(1, :S1)]
    @test mesh["surface_sets"]["RIGHT.TOP"] == [(2, :S1)]
end

@testset "Translation is applied before axis-angle rotation" begin
    input = """
    *PART, NAME=BAR
    *NODE
    1, 1.0, 0.0, 0.0
    2, 2.0, 0.0, 0.0
    *ELEMENT, TYPE=B31, ELSET=BAR
    1, 1, 2
    *END PART
    *ASSEMBLY, NAME=A
    *INSTANCE, NAME=ROTATED, PART=BAR
    1.0, 0.0, 0.0
    0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 90.0
    *END INSTANCE
    *END ASSEMBLY
    """

    mesh = abaqus_parse_mesh(input)
    @test mesh["nodes"][1] ≈ [0.0, 2.0, 0.0] atol=1.0e-12
    @test mesh["nodes"][2] ≈ [0.0, 3.0, 0.0] atol=1.0e-12
    rotation = mesh["assembly"]["instances"]["ROTATED"]["rotation"]
    @test rotation["axis_start"] == [0.0, 0.0, 0.0]
    @test rotation["axis_end"] == [0.0, 0.0, 1.0]
    @test rotation["angle_degrees"] == 90.0
end

@testset "PART-only assembly input retains deterministic fallback" begin
    input = """
    *PART, NAME=ONLY
    *NODE
    1, 0.0, 0.0, 0.0
    2, 1.0, 0.0, 0.0
    3, 0.0, 1.0, 0.0
    *ELEMENT, TYPE=S3, ELSET=FACE
    1, 1, 2, 3
    *END PART
    """

    mesh = abaqus_parse_mesh(input)
    @test isempty(mesh["assembly"]["instances"])
    @test isempty(mesh["instance_parts"])
    @test mesh["element_sets"]["ONLY.FACE"] == [1]
    @test mesh["nodes"][1] == [0.0, 0.0, 0.0]
end

@testset "Flat format still works" begin
    input = """
    *HEADING
    Flat format model
    *NODE
    1, 0.0, 0.0, 0.0
    2, 1.0, 0.0, 0.0
    3, 1.0, 1.0, 0.0
    4, 0.0, 1.0, 0.0
    *ELEMENT, TYPE=CPS4, ELSET=PART1
    1, 1, 2, 3, 4
    """

    mesh = abaqus_parse_mesh(input)
    @test length(mesh["nodes"]) == 4
    @test length(mesh["elements"]) == 1
    @test mesh["element_sets"]["PART1"] == [1]
end

@testset "Malformed instance declarations fail clearly" begin
    unknown_part = """
    *PART, NAME=KNOWN
    *NODE
    1, 0.0, 0.0, 0.0
    *END PART
    *ASSEMBLY, NAME=A
    *INSTANCE, NAME=BAD, PART=MISSING
    *END INSTANCE
    *END ASSEMBLY
    """
    @test_throws ArgumentError abaqus_parse_mesh(unknown_part)

    duplicate_instance = """
    *PART, NAME=P
    *NODE
    1, 0.0, 0.0, 0.0
    *END PART
    *ASSEMBLY, NAME=A
    *INSTANCE, NAME=SAME, PART=P
    *END INSTANCE
    *INSTANCE, NAME=SAME, PART=P
    *END INSTANCE
    *END ASSEMBLY
    """
    @test_throws ArgumentError abaqus_parse_mesh(duplicate_instance)

    malformed_translation = """
    *PART, NAME=P
    *NODE
    1, 0.0, 0.0, 0.0
    *END PART
    *ASSEMBLY, NAME=A
    *INSTANCE, NAME=BAD, PART=P
    1.0, 2.0
    *END INSTANCE
    *END ASSEMBLY
    """
    @test_throws ArgumentError abaqus_parse_mesh(malformed_translation)

    zero_axis = """
    *PART, NAME=P
    *NODE
    1, 1.0, 0.0, 0.0
    *END PART
    *ASSEMBLY, NAME=A
    *INSTANCE, NAME=BAD, PART=P
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 90.0
    *END INSTANCE
    *END ASSEMBLY
    """
    @test_throws ArgumentError abaqus_parse_mesh(zero_axis)
end
