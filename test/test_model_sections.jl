using Test
using AbaqusReader

@testset "model sections and types" begin
    @testset "comprehensive model parsing" begin
        # Create a comprehensive test input file with all section types
        inp_content = """
*HEADING
Comprehensive test model for all section types

*NODE
1, 0.0, 0.0, 0.0
2, 1.0, 0.0, 0.0
3, 1.0, 1.0, 0.0
4, 0.0, 1.0, 0.0
5, 0.0, 0.0, 1.0
6, 1.0, 0.0, 1.0
7, 1.0, 1.0, 1.0
8, 0.0, 1.0, 1.0

*NSET, NSET=ALL_NODES
1, 2, 3, 4, 5, 6, 7, 8

*ELEMENT, TYPE=C3D8, ELSET=VOLUME
1, 1, 2, 3, 4, 5, 6, 7, 8

*ELEMENT, TYPE=S4, ELSET=SHELL_ELEMENTS
200, 1, 2, 3, 4

*MATERIAL, NAME=STEEL
*ELASTIC
210000.0, 0.3
*DENSITY
7850.0
*PLASTIC
235.0, 0.0
300.0, 0.1
*EXPANSION
1.2E-5
*DAMPING, ALPHA=0.01, BETA=0.02

*SOLID SECTION, ELSET=VOLUME, MATERIAL=STEEL

*SHELL SECTION, ELSET=SHELL_ELEMENTS, MATERIAL=STEEL
0.01, 5

*STEP, NAME=STATIC_STEP, NLGEOM=YES
Static analysis with nonlinear geometry
*STATIC
0.1, 1.0, 1E-5, 0.1
*BOUNDARY
ALL_NODES, 1, 3, 0.0
*CLOAD
1, 1, 1000.0
*DLOAD
1, P1, 10.0
*DSLOAD
1, S1, 5.0
*NODE PRINT, NSET=ALL_NODES, FREQUENCY=1
U, RF
*EL PRINT, ELSET=VOLUME
S, E
*SECTION PRINT, NAME=SECTION1
SOF
*NODE FILE, NSET=ALL_NODES
U, RF
*EL FILE, ELSET=VOLUME
S
*CONTACT FILE
CSTRESS
*NODE OUTPUT
U, RF
*ELEMENT OUTPUT
S, E
*ENERGY OUTPUT
ALLSE
*CONTACT OUTPUT
CSTRESS
*END STEP

*STEP, NAME=FREQUENCY_STEP, PERTURBATION
Eigenvalue extraction
*FREQUENCY, EIGENSOLVER=LANCZOS
5, , , 100.0
*END STEP
"""

        # Parse the model directly from string (no file I/O needed!)
        model = abaqus_parse_model(inp_content)

        @testset "model structure" begin
            @test isa(model, AbaqusReader.Model)
            @test model.name == "model"  # Default name for string parsing
        end

        @testset "mesh" begin
            @test length(model.mesh.nodes) == 8
            @test length(model.mesh.elements) == 2  # volume + shell
            @test haskey(model.mesh.node_sets, "ALL_NODES")
            @test haskey(model.mesh.element_sets, "VOLUME")
            @test haskey(model.mesh.element_sets, "SHELL_ELEMENTS")
        end

        @testset "materials" begin
            @test haskey(model.materials, :STEEL)
            steel = model.materials[:STEEL]
            @test isa(steel, AbaqusReader.Material)
            @test steel.name == :STEEL
            @test length(steel.properties) == 5  # elastic, density, plastic, expansion, damping

            # Check Elastic property
            elastic = findfirst(p -> isa(p, AbaqusReader.Elastic), steel.properties)
            @test elastic !== nothing
            @test steel.properties[elastic].E == 210000.0
            @test steel.properties[elastic].nu == 0.3

            # Check Density
            density = findfirst(p -> isa(p, AbaqusReader.Density), steel.properties)
            @test density !== nothing
            @test steel.properties[density].density == 7850.0

            # Check Plastic
            plastic = findfirst(p -> isa(p, AbaqusReader.Plastic), steel.properties)
            @test plastic !== nothing
            @test length(steel.properties[plastic].table) == 2
            @test steel.properties[plastic].table[1] == (235.0, 0.0)
            @test steel.properties[plastic].table[2] == (300.0, 0.1)

            # Check Expansion
            expansion = findfirst(p -> isa(p, AbaqusReader.Expansion), steel.properties)
            @test expansion !== nothing
            @test steel.properties[expansion].alpha == 1.2E-5

            # Check Damping
            damping = findfirst(p -> isa(p, AbaqusReader.Damping), steel.properties)
            @test damping !== nothing
            @test steel.properties[damping].alpha == 0.01
            @test steel.properties[damping].beta == 0.02
        end

        @testset "properties" begin
            @test length(model.properties) == 2  # solid, shell

            # Check SolidSection
            solid = findfirst(p -> isa(p, AbaqusReader.SolidSection), model.properties)
            @test solid !== nothing
            @test model.properties[solid].element_set == :VOLUME
            @test model.properties[solid].material_name == :STEEL

            # Check ShellSection
            shell = findfirst(p -> isa(p, AbaqusReader.ShellSection), model.properties)
            @test shell !== nothing
            @test model.properties[shell].element_set == Symbol("SHELL_ELEMENTS")
            @test model.properties[shell].material_name == :STEEL
            @test model.properties[shell].thickness == 0.01
            @test model.properties[shell].num_integration_points == 5
        end

        @testset "steps" begin
            @test length(model.steps) == 2

            # Check static step
            static_step = model.steps[1]
            @test static_step.name == "STATIC_STEP"
            @test static_step.kind == :STATIC
            @test haskey(static_step.options, "NLGEOM")
            @test static_step.options["NLGEOM"] == "YES"
            @test length(static_step.parameters) == 4
            @test static_step.parameters[1] == 0.1  # initial time increment
            @test static_step.parameters[2] == 1.0  # total time

            # Check boundary conditions in static step
            @test length(static_step.boundary_conditions) == 4  # BOUNDARY, CLOAD, DLOAD, DSLOAD

            boundary = findfirst(bc -> bc.kind == :BOUNDARY, static_step.boundary_conditions)
            @test boundary !== nothing

            cload = findfirst(bc -> bc.kind == :CLOAD, static_step.boundary_conditions)
            @test cload !== nothing

            dload = findfirst(bc -> bc.kind == :DLOAD, static_step.boundary_conditions)
            @test dload !== nothing

            dsload = findfirst(bc -> bc.kind == :DSLOAD, static_step.boundary_conditions)
            @test dsload !== nothing

            # Check output requests
            @test length(static_step.output_requests) >= 7  # NODE PRINT, EL PRINT, etc.

            # Check frequency step
            freq_step = model.steps[2]
            @test freq_step.name == "FREQUENCY_STEP"
            @test freq_step.kind == :FREQUENCY
            @test haskey(freq_step.options, "PERTURBATION")
            @test freq_step.options["PERTURBATION"] === true  # Boolean flag
            # Note: EIGENSOLVER is an option on *FREQUENCY, not *STEP
            # It's not stored in step.options but processed during FREQUENCY parsing
        end
    end

    @testset "type constructors" begin
        # Test Mesh constructor from dict
        mesh_dict = Dict{String,Dict}(
            "nodes" => Dict(1 => [0.0, 0.0, 0.0]),
            "node_sets" => Dict("NSET1" => [1]),
            "elements" => Dict(1 => [1, 2, 3]),
            "element_types" => Dict(1 => :C3D8),
            "element_sets" => Dict("ELSET1" => [1]),
            "surface_sets" => Dict{String,Vector{Tuple{Int,Symbol}}}(),
            "surface_types" => Dict{String,Symbol}()
        )

        mesh = AbaqusReader.Mesh(mesh_dict)
        @test isa(mesh, AbaqusReader.Mesh)
        @test length(mesh.nodes) == 1
        @test haskey(mesh.node_sets, "NSET1")
    end
end
