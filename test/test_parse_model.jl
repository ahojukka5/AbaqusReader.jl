# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader: abaqus_read_model
using AbaqusReader: parse_keyword

datadir = joinpath(@__DIR__, first(splitext(basename(@__FILE__))))

@testset "parse abaqus inp file to AbaqusModel" begin
    fn = joinpath(datadir, "cube_tet4.inp")
    model = abaqus_read_model(fn)

    @test length(model.properties) == 1
    section = first(model.properties)
    @test section.element_set == :CUBE
    @test section.material_name == :MAT

    @test haskey(model.materials, :MAT)
    material = model.materials[:MAT]
    @test isapprox(first(material.properties).E, 208.0e3)

    @test length(model.steps) == 1
    step = first(model.steps)
    @test length(step.boundary_conditions) == 2

    bc = step.boundary_conditions[1]
    @test bc.data[1] == [:SYM23, 1]
    @test bc.data[2] == [:SYM13, 2]

    load = step.boundary_conditions[2]
    @test load.data[1] == [:LOAD, :P, 1.00000]
end

@testset "parse keyword" begin
    k = parse_keyword("*SURFACE, NAME=TIE, SURFACE TO SURFACE")
    @test k.options[1] == ("NAME" => "TIE")
    @test k.options[2] == "SURFACE TO SURFACE"
    @test_throws(Exception, parse_keyword("*SURFACE, MOI=HEI=EI"))
end
