# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

using AbaqusReader: abaqus_read_mesh
using Test

datadir = joinpath(@__DIR__, first(splitext(basename(@__FILE__))))
filename = joinpath(datadir, "mesh.inp")
mesh = abaqus_read_mesh(filename)
@test length(mesh["elements"]) == 7
