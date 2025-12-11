# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader
using Test

# Helper function to capture exception message while suppressing error output
function capture_exception_message(f)
    # Suppress stderr to avoid printing error messages during tests
    old_stderr = stderr
    redirect_stderr(devnull)
    try
        try
            f()
            return nothing
        catch e
            return e isa ErrorException ? e.msg : nothing
        finally
            redirect_stderr(old_stderr)
        end
    catch
        redirect_stderr(old_stderr)
        rethrow()
    end
end

@testset "Register element dynamically" begin
    # Test registering a new element type
    @testset "Basic registration" begin
        # Register a hypothetical C3D10I element (incompatible mode tet)
        register_element!("C3D10I", 10, "Tet10")

        # Verify it can be queried
        @test AbaqusReader.element_has_nodes(:C3D10I) == 10
        @test AbaqusReader.element_has_type(:C3D10I) == :Tet10
    end

    @testset "Parse mesh with registered element" begin
        # Register C3D8RT (8-node reduced integration thermal hex)
        register_element!("C3D8RT", 8, "Hex8")

        # Create a simple mesh using the registered element
        inp_content = """
        *HEADING
        Test mesh with C3D8RT elements
        *NODE
        1, 0.0, 0.0, 0.0
        2, 1.0, 0.0, 0.0
        3, 1.0, 1.0, 0.0
        4, 0.0, 1.0, 0.0
        5, 0.0, 0.0, 1.0
        6, 1.0, 0.0, 1.0
        7, 1.0, 1.0, 1.0
        8, 0.0, 1.0, 1.0
        *ELEMENT, TYPE=C3D8RT
        1, 1, 2, 3, 4, 5, 6, 7, 8
        """

        mesh = abaqus_parse_mesh(inp_content)
        @test haskey(mesh["elements"], 1)
        @test length(mesh["elements"][1]) == 8
        @test mesh["element_types"][1] == :Hex8
    end

    @testset "Error message for unknown element" begin
        # Try to parse mesh with unknown element type
        inp_content = """
        *NODE
        1, 0.0, 0.0, 0.0
        *ELEMENT, TYPE=UNKNOWN_ELEM_XYZ
        1, 1
        """

        # Test that the correct exception is thrown (suppress error output)
        old_stderr = stderr
        redirect_stderr(devnull)
        try
            @test_throws ErrorException abaqus_parse_mesh(inp_content)
        finally
            redirect_stderr(old_stderr)
        end
        
        # Check the error message content
        err_msg = capture_exception_message(() -> abaqus_parse_mesh(inp_content))
        @test err_msg !== nothing
        @test occursin("Unknown ABAQUS element type: UNKNOWN_ELEM_XYZ", err_msg)
        @test occursin("register_element!", err_msg)
        @test occursin("data/abaqus_elements.toml", err_msg)
    end

    @testset "Case insensitive registration" begin
        # ABAQUS element names are case-insensitive, but we uppercase them
        register_element!("cpe3", 3, "Tri3")

        # Should be stored as uppercase
        @test AbaqusReader.element_has_nodes(:CPE3) == 3
        @test AbaqusReader.element_has_type(:CPE3) == :Tri3
    end
end
