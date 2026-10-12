using AbaqusReader: abaqus_download
using AbaqusReader: abaqus_read_mesh
using AbaqusReader: parse_keyword

@testset "parse abaqus t2d2 inp file to AbaqusMesh" begin
    if haskey(ENV, "ABAQUS_DOWNLOAD_URL")
        fn = abaqus_download("et22sfse.inp")
        mesh = abaqus_read_mesh(fn)
        node_dict = mesh["nodes"]
        elem_dict = mesh["elements"]
        elem_types=mesh["element_types"]
        @test isapprox(node_dict[1], [5.0, 10.0])
        @test isapprox(node_dict[2], [10.0, 10.0])
        @test isapprox(node_dict[3], [15.0, 10.0])
        @test isapprox(node_dict[4], [10.0, 0.0])
        @test Set(mesh["element_sets"][String(:EALL)])== Set(1:3)
        @test elem_dict[1]== [4, 1]
        @test elem_dict[2]==[4, 2]
        @test elem_dict[3]== [4, 3]
        @test elem_types[1] == :Seg2
        @test elem_types[2] == :Seg2
        @test elem_types[3] == :Seg2
        #@test mesh.element_codes[1] = :T2D2
        #@test mesh.element_codes[2] = :T2D2
        #@test mesh.element_codes[3] = :T2D2
    end
end

@testset "parse abaqus t3d2 inp file to AbaqusMesh" begin
    if haskey(ENV, "ABAQUS_DOWNLOAD_URL")
        fn = abaqus_download("et32sfse.inp")
        mesh = abaqus_read_mesh(fn)
        node_dict = mesh["nodes"]
        elem_dict = mesh["elements"]
        elem_types=mesh["element_types"]
        @test isapprox(node_dict[1], [5.0, 10.0])
        @test isapprox(node_dict[2], [10.0, 10.0])
        @test isapprox(node_dict[3], [15.0, 10.0])
        @test isapprox(node_dict[4], [10.0, 0.0])
        @test Set(mesh["element_sets"][String(:EALL)])== Set(1:3)
        @test elem_dict[1]== [4, 1]
        @test elem_dict[2]==[4, 2]
        @test elem_dict[3]== [4, 3]
        @test elem_types[1] == :Seg2
        @test elem_types[2] == :Seg2
        @test elem_types[3] == :Seg2
        #@test mesh.element_codes[1] = :T2D2
        #@test mesh.element_codes[2] = :T2D2
        #@test mesh.element_codes[3] = :T2D2
    end
end
