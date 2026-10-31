using AbaqusReader: abaqus_read_mesh
using Test

datadir = joinpath(@__DIR__, first(splitext(basename(@__FILE__))))

function pinned_truss(filename)
    return abaqus_read_mesh(joinpath(datadir, filename))
end

@testset "parse abaqus t2d2 inp file to AbaqusMesh" begin
    mesh = pinned_truss("t2d2.inp")
    @test mesh["nodes"][1] == [5.0, 10.0]
    @test mesh["nodes"][2] == [10.0, 10.0]
    @test mesh["nodes"][3] == [15.0, 10.0]
    @test mesh["nodes"][4] == [10.0, 0.0]
    @test all(coords -> length(coords) == 2, values(mesh["nodes"]))
    @test Set(mesh["element_sets"]["EALL"]) == Set(1:3)
    @test mesh["elements"][1] == [4, 1]
    @test mesh["elements"][2] == [4, 2]
    @test mesh["elements"][3] == [4, 3]
    @test mesh["element_types"][1] == :Seg2
    @test mesh["element_types"][2] == :Seg2
    @test mesh["element_types"][3] == :Seg2
    @test mesh["element_codes"][1] == :T2D2
    @test mesh["element_codes"][2] == :T2D2
    @test mesh["element_codes"][3] == :T2D2
end

@testset "parse abaqus t3d2 inp file to AbaqusMesh" begin
    mesh = pinned_truss("t3d2.inp")
    @test mesh["nodes"][1] == [5.0, 10.0, 1.0]
    @test mesh["nodes"][2] == [10.0, 10.0, 2.0]
    @test mesh["nodes"][3] == [15.0, 10.0, 3.0]
    @test mesh["nodes"][4] == [10.0, 0.0, 0.0]
    @test all(coords -> length(coords) == 3, values(mesh["nodes"]))
    @test Set(mesh["element_sets"]["EALL"]) == Set(1:3)
    @test mesh["elements"][1] == [4, 1]
    @test mesh["elements"][2] == [4, 2]
    @test mesh["elements"][3] == [4, 3]
    @test mesh["element_types"][1] == :Seg2
    @test mesh["element_types"][2] == :Seg2
    @test mesh["element_types"][3] == :Seg2
    @test mesh["element_codes"][1] == :T3D2
    @test mesh["element_codes"][2] == :T3D2
    @test mesh["element_codes"][3] == :T3D2
end
