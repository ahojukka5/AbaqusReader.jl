# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader: element_has_type, element_has_nodes, parse_abaqus,
    parse_section, abaqus_read_mesh

datadir = joinpath(@__DIR__, first(splitext(basename(@__FILE__))))

@testset "parse beam.inp mesh" begin
    fn = joinpath(datadir, "beam.inp")
    mesh = open(parse_abaqus, fn)
    @test length(mesh["nodes"]) == 298
    @test length(mesh["elements"]) == 120
    @test length(mesh["element_sets"]["Body1"]) == 120
    @test length(mesh["node_sets"]["SUPPORT"]) == 9
    @test length(mesh["node_sets"]["LOAD"]) == 9
    @test length(mesh["node_sets"]["TOP"]) == 83
end

@testset "test read element section" begin
    data = """*ELEMENT, TYPE=C3D10, ELSET=BEAM
    1,       243,       240,       191,       117,       245,       242,       244,
    1,         2,       196
    2,       204,       199,       175,       130,       207,       208,       209,
    3,         4,       176
    """
    data = split(data, "\n")
    model = Dict{String,Any}()
    model["node_sets"] = Dict{String,Vector{Int}}()
    model["elements"] = Dict{Int,Vector{Int}}()
    model["element_sets"] = Dict{String,Vector{Int}}()
    model["element_types"] = Dict{Int,Symbol}()
    model["element_codes"] = Dict{Int,Symbol}()
    parse_section(model, data, :ELEMENT, 1, 5, Val{:ELEMENT})
    @test length(model["elements"]) == 2
    @test model["element_sets"]["BEAM"] == [1, 2]
    @test model["elements"][1] == [243, 240, 191, 117, 245, 242, 244, 1, 2, 196]
    @test model["elements"][2] == [204, 199, 175, 130, 207, 208, 209, 3, 4, 176]
end


@testset "parse cube_tet4.inp mesh" begin
    fn = joinpath(datadir, "cube_tet4.inp")
    mesh = open(parse_abaqus, fn)
    @test length(mesh["nodes"]) == 10
    @test length(mesh["elements"]) == 17
    @test haskey(mesh["elements"], 1)
    @test mesh["elements"][1] == [8, 10, 1, 2]
    @test mesh["element_types"][1] == :Tet4
    @test haskey(mesh["node_sets"], "SYM12")
    @test haskey(mesh["element_sets"], "CUBE")
    @test haskey(mesh["surface_sets"], "LOAD")
    @test haskey(mesh["surface_sets"], "ORDER")
    @test length(mesh["surface_sets"]["LOAD"]) == 2
    @test mesh["surface_sets"]["LOAD"][1] == (16, :S1)
    @test mesh["surface_types"]["LOAD"] == :ELEMENT
    @test length(Set(map(size, values(mesh["nodes"])))) == 1
end

@testset "parse nodes from abaqus .inp file to Mesh (NX export)" begin
    fn = joinpath(datadir, "nx_export_problem.inp")
    mesh = open(parse_abaqus, fn)
    @test length(mesh["nodes"]) == 3
end

@testset "parse abaqus .inp created using hypermesh" begin
    fn = joinpath(datadir, "hypermesh_model.inp")
    mesh = abaqus_read_mesh(fn)
    @test length(mesh["nodes"]) == 2
end

@testset "find element types and nodes" begin
    # Test 3D solid elements
    @test element_has_nodes(Val{:C3D4}) == 4
    @test element_has_type(Val{:C3D4}) == :Tet4
    @test element_has_nodes(Val{:C3D8}) == 8
    @test element_has_type(Val{:C3D8}) == :Hex8
    @test element_has_nodes(Val{:C3D8R}) == 8
    @test element_has_type(Val{:C3D8R}) == :Hex8
    @test element_has_nodes(Val{:C3D10}) == 10
    @test element_has_type(Val{:C3D10}) == :Tet10
    @test element_has_nodes(Val{:C3D10R}) == 10
    @test element_has_type(Val{:C3D10R}) == :Tet10
    @test element_has_nodes(Val{:C3D20}) == 20
    @test element_has_nodes(Val{:C3D20E}) == 20
    @test element_has_nodes(Val{:C3D20R}) == 20
    @test element_has_nodes(Val{:C3D15}) == 15
    @test element_has_type(Val{:C3D15}) == :Wedge15

    # Test shell elements
    @test element_has_nodes(Val{:S3}) == 3
    @test element_has_type(Val{:S3}) == :Tri3
    @test element_has_nodes(Val{:S3R}) == 3
    @test element_has_type(Val{:S3R}) == :Tri3
    @test element_has_nodes(Val{:S4R}) == 4
    @test element_has_type(Val{:S4R}) == :Quad4
    @test element_has_nodes(Val{:STRI65}) == 6
    @test element_has_type(Val{:STRI65}) == :Tri6

    # Test 2D plane elements
    @test element_has_nodes(Val{:CPS4}) == 4
    @test element_has_type(Val{:CPS4}) == :Quad4
    @test element_has_nodes(Val{:CPS4R}) == 4
    @test element_has_type(Val{:CPS4R}) == :Quad4
    @test element_has_nodes(Val{:CPE3}) == 3
    @test element_has_type(Val{:CPE3}) == :Tri3
    @test element_has_nodes(Val{:CPE4R}) == 4
    @test element_has_type(Val{:CPE4R}) == :Quad4
    @test element_has_nodes(Val{:CAX4}) == 4
    @test element_has_type(Val{:CAX4}) == :Quad4
    @test element_has_nodes(Val{:CAX4R}) == 4
    @test element_has_type(Val{:CAX4R}) == :Quad4

    # Test beam elements
    @test element_has_nodes(Val{:B31}) == 2
    @test element_has_type(Val{:B31}) == :Seg2
    @test element_has_nodes(Val{:B32}) == 3
    @test element_has_type(Val{:B32}) == :Seg3
end

@testset "use GENERATE keyword" begin
    data = """
*NSET, NSET=testgen, GENERATE
7,13,2
"""
    fn = tempname() * ".inp"
    open(fn, "w") do fid
        write(fid, data)
    end
    mesh = open(parse_abaqus, fn)
    @test mesh["node_sets"]["testgen"] == [7, 9, 11, 13]
end

@testset "parse ELSET" begin
    lines = ["*ELSET, ELSET=TEST1", "1"]
    mesh = Dict("element_sets" => Dict{String,Vector{Int}}())
    parse_section(mesh, lines, :ELSET, 1, 2, Val{:ELSET})
    @test mesh["element_sets"]["TEST1"] == [1]
end

@testset "parse tet4.inp" begin
    fn = joinpath(datadir, "tet4.inp")
    mesh = abaqus_read_mesh(fn)
    @test length(mesh["nodes"]) == 116
end

@testset "Set names" begin
    data = """*Nset, nset=Without quotes
    1,2,3
    *Nset, nset="With quotes"
    3,4,5
    *Nset, nset="With wrong quotes
    1,2,3
    *Elset, elset=Without quotes
    1,2,3
    *Elset, elset="With quotes"
    3,4,5
    *Elset, elset="With wrong quotes
    1,2,3
    """
    data = split(data, "\n")
    model = Dict{String,Any}()
    model["node_sets"] = Dict{String,Vector{Int}}()
    model["element_sets"] = Dict{String,Vector{Int}}()
    @test parse_section(model, data, :NSET, 1, 2, Val{:NSET}) == [1, 2, 3]
    @test parse_section(model, data, :NSET, 3, 4, Val{:NSET}) == [3, 4, 5]
    @test_throws ErrorException parse_section(model, data, :NSET, 5, 6, Val{:NSET})
    @test keys(model["node_sets"]) == Set(["Without", "With quotes"])
    @test parse_section(model, data, :ELSET, 7, 8, Val{:ELSET}) == [1, 2, 3]
    @test parse_section(model, data, :ELSET, 9, 10, Val{:ELSET}) == [3, 4, 5]
    @test_throws ErrorException parse_section(model, data, :ELSET, 11, 12, Val{:NSET})
    @test keys(model["element_sets"]) == Set(["Without", "With quotes"])
end

@testset "DCOUP3D element" begin
    data = """*ELEMENT, TYPE=DCOUP3D
    1, 100
    """
    data = split(data, "\n")
    model = Dict{String,Any}()
    model["node_sets"] = Dict{String,Vector{Int}}()
    model["elements"] = Dict{Int,Vector{Int}}()
    model["element_sets"] = Dict{String,Vector{Int}}()
    model["element_types"] = Dict{Int,Symbol}()
    model["element_codes"] = Dict{Int,Symbol}()
    parse_section(model, data, :ELEMENT, 1, 2, Val{:ELEMENT})
    @test haskey(model, "elements")
    @test haskey(model, "element_types")
    @test model["element_types"][1] == :Poi1
    @test model["elements"][1] == [100]
    @test length(model["elements"][1]) == 1
end
