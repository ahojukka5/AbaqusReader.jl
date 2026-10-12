using AbaqusReader
using Test

@testset "SOLID SECTION with area parameter for T2D2 elements" begin
    # Test case from issue #36
    inp_content = """
    *HEADING
    Truss model with area
    *NODE
    1, 0.0, 0.0
    2, 10.0, 0.0
    *ELEMENT, TYPE=T2D2, ELSET=EALL
    1, 1, 2
    *MATERIAL,NAME=ALUM
    *ELASTIC
    1E7,.3
    *SOLID SECTION,ELSET=EALL,MATERIAL=ALUM
    .0625
    """

    model = abaqus_parse_model(inp_content)

    # Check that the model parsed successfully
    @test length(model.properties) == 1

    # Check the solid section property
    property = model.properties[1]
    @test property isa AbaqusReader.SolidSection
    @test property.element_set == :EALL
    @test property.material_name == :ALUM

    # Check that area was parsed
    @test hasfield(typeof(property), :area)
    @test property.area == 0.0625
end

@testset "SOLID SECTION without area parameter" begin
    # Standard solid section for 3D elements (no area needed)
    inp_content = """
    *HEADING
    3D solid model
    *NODE
    1, 0.0, 0.0, 0.0
    2, 1.0, 0.0, 0.0
    3, 1.0, 1.0, 0.0
    4, 0.0, 1.0, 0.0
    5, 0.0, 0.0, 1.0
    6, 1.0, 0.0, 1.0
    7, 1.0, 1.0, 1.0
    8, 0.0, 1.0, 1.0
    *ELEMENT, TYPE=C3D8, ELSET=EALL
    1, 1, 2, 3, 4, 5, 6, 7, 8
    *MATERIAL,NAME=STEEL
    *ELASTIC
    2.1E11, 0.3
    *SOLID SECTION,MATERIAL=STEEL,ELSET=EALL
    """

    model = abaqus_parse_model(inp_content)

    # Check that the model parsed successfully
    @test length(model.properties) == 1

    # Check the solid section property
    property = model.properties[1]
    @test property isa AbaqusReader.SolidSection
    @test property.element_set == :EALL
    @test property.material_name == :STEEL

    # Area should be nothing for non-truss elements
    @test hasfield(typeof(property), :area)
    @test property.area === nothing
end

@testset "SOLID SECTION with area and trailing comma" begin
    # Test case variation from issue #36
    inp_content = """
    *HEADING
    Truss with trailing comma
    *NODE
    1, 0.0, 0.0
    2, 10.0, 0.0
    *ELEMENT, TYPE=T2D2, ELSET=EALL
    1, 1, 2
    *SOLID SECTION,MATERIAL=ALUM, ELSET=EALL
    .0625,
    *MATERIAL,NAME=ALUM
    *ELASTIC
    1E7, 0.3
    """

    model = abaqus_parse_model(inp_content)

    # Check that area was parsed even with trailing comma
    property = model.properties[1]
    @test property.area == 0.0625
end
