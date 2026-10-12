using AbaqusReader: abaqus_read_mesh
using Test

datadir = joinpath(@__DIR__, first(splitext(basename(@__FILE__))))
filename = joinpath(datadir, "mesh.inp")
mesh = abaqus_read_mesh(filename)
@test length(mesh["elements"]) == 7
