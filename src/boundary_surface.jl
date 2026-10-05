# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

"""
One corner-node triangle on an Abaqus mesh surface.

`nodes` are global node ids. For a volume element the winding is outward.
`element_id` is the key in `mesh["elements"]` of the element that contributed
the face. Shell and membrane faces keep `element_boundary` corner order.
"""
struct SurfaceTriangle
    nodes::NTuple{3,Int}
    element_id::Int
    topology::Symbol
end

struct SurfaceFace
    nodes::Vector{Int}
    element_id::Int
    topology::Symbol
end

function surface_coordinates(nodes, node_id::Int)
    coordinates = get(nodes, node_id, nothing)
    coordinates === nothing && throw(ArgumentError(
        "element references missing node $node_id",
    ))
    length(coordinates) >= 1 || throw(ArgumentError(
        "node $node_id has no coordinates",
    ))
    return (
        Float64(coordinates[1]),
        length(coordinates) >= 2 ? Float64(coordinates[2]) : 0.0,
        length(coordinates) >= 3 ? Float64(coordinates[3]) : 0.0,
    )
end

function surface_subtract(a, b)
    return (a[1] - b[1], a[2] - b[2], a[3] - b[3])
end

function surface_cross(a, b)
    return (
        a[2] * b[3] - a[3] * b[2],
        a[3] * b[1] - a[1] * b[3],
        a[1] * b[2] - a[2] * b[1],
    )
end

function surface_dot(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

function surface_centroid(nodes, node_ids)
    total = (0.0, 0.0, 0.0)
    for node_id in node_ids
        point = surface_coordinates(nodes, Int(node_id))
        total = (
            total[1] + point[1],
            total[2] + point[2],
            total[3] + point[3],
        )
    end
    scale = 1.0 / length(node_ids)
    return (total[1] * scale, total[2] * scale, total[3] * scale)
end

function orient_surface_outward(nodes, face_nodes, element_nodes)
    length(face_nodes) >= 3 || return Int.(face_nodes)
    p1 = surface_coordinates(nodes, Int(face_nodes[1]))
    p2 = surface_coordinates(nodes, Int(face_nodes[2]))
    p3 = surface_coordinates(nodes, Int(face_nodes[3]))
    normal = surface_cross(surface_subtract(p2, p1), surface_subtract(p3, p1))
    face_center = surface_centroid(nodes, face_nodes)
    element_center = surface_centroid(nodes, element_nodes)
    direction = surface_subtract(face_center, element_center)
    return surface_dot(normal, direction) < 0 ? reverse(Int.(face_nodes)) :
        Int.(face_nodes)
end

function surface_local_nodes(connectivity, positions, element_id::Int)
    maximum(positions) <= length(connectivity) || throw(ArgumentError(
        "element $element_id has too few nodes for its topology",
    ))
    return [Int(connectivity[position]) for position in positions]
end

function surface_topology(value)
    return value isa Symbol ? value : Symbol(value)
end

function increment_surface_count!(counts::Dict{String,Int}, key)
    name = string(key)
    counts[name] = get(counts, name, 0) + 1
    return counts[name]
end

function surface_double_area(nodes, triangle_nodes::NTuple{3,Int})
    p1 = surface_coordinates(nodes, triangle_nodes[1])
    p2 = surface_coordinates(nodes, triangle_nodes[2])
    p3 = surface_coordinates(nodes, triangle_nodes[3])
    normal = surface_cross(surface_subtract(p2, p1), surface_subtract(p3, p1))
    return sqrt(surface_dot(normal, normal))
end

function triangulate_surface_quad(nodes, face_nodes, element_id::Int, topology::Symbol)
    primary = (
        SurfaceTriangle((face_nodes[1], face_nodes[2], face_nodes[3]), element_id, topology),
        SurfaceTriangle((face_nodes[1], face_nodes[3], face_nodes[4]), element_id, topology),
    )
    all(
        surface_double_area(nodes, triangle.nodes) > eps(Float64)
        for triangle in primary
    ) && return primary

    alternate = (
        SurfaceTriangle((face_nodes[1], face_nodes[2], face_nodes[4]), element_id, topology),
        SurfaceTriangle((face_nodes[2], face_nodes[3], face_nodes[4]), element_id, topology),
    )
    all(
        surface_double_area(nodes, triangle.nodes) > eps(Float64)
        for triangle in alternate
    ) && return alternate

    return primary
end

function triangulate_surface_face(nodes, face_nodes, element_id::Int, topology::Symbol)
    if length(face_nodes) == 3
        return (SurfaceTriangle(
            (face_nodes[1], face_nodes[2], face_nodes[3]),
            element_id,
            topology,
        ),)
    elseif length(face_nodes) == 4
        return triangulate_surface_quad(nodes, face_nodes, element_id, topology)
    else
        throw(ArgumentError(
            "boundary face has unsupported node count $(length(face_nodes))",
        ))
    end
end

"""
    boundary_surface(mesh::AbstractDict)

Corner-node surface triangles for one mesh returned by [`abaqus_read_mesh`](@ref).

Volume topologies contribute a face only when that sorted corner-node set
belongs to exactly one element. A face shared by two elements is an interior
face and is omitted. A face shared by more than two elements is non-manifold
and is omitted. Surviving volume faces are wound outward from the centroid of
the element's corner nodes (midside nodes are not part of that centroid).
The recorded `element_id` is the lowest element id that carried the face.

Triangular and quadrilateral elements contribute their single
[`element_boundary`](@ref) corner face. Those faces are not matched against
other elements and are not reoriented. Point and line topologies are counted
and omitted. Unknown topologies are counted and omitted.

Quadrilaterals become two triangles. The split is corners `(1, 2, 3)` and
`(1, 3, 4)`. When either triangle has double-area at most `eps(Float64)`, the
other diagonal is used if both of those triangles are larger than that
tolerance. Double-area is the length of the cross product of two edges.
A flat face that cannot be saved is still returned on the primary diagonal.

Exterior volume triangles are emitted in lexicographic order of their sorted
node-id keys. Explicit surface triangles follow, in ascending element-id
order. That order is the primitive order a consumer should preserve.

The named tuple fields are:

- `triangles::Vector{SurfaceTriangle}`
- `volume_boundary_face_count`
- `surface_element_face_count`
- `nonmanifold_face_count`
- `unsupported_topologies::Dict{String,Int}`, with `"missing"` when an element
  has no type
- `skipped_topologies::Dict{String,Int}`
- `linearized_topologies::Vector{String}`, sorted topology names whose
  boundary dropped midside or center nodes
"""
function boundary_surface(mesh::AbstractDict)
    nodes = get(mesh, "nodes", Dict())
    elements = get(mesh, "elements", Dict())
    element_types = get(mesh, "element_types", Dict())

    face_records = Dict{Tuple,SurfaceFace}()
    face_counts = Dict{Tuple,Int}()
    surface_faces = SurfaceFace[]
    unsupported = Dict{String,Int}()
    skipped = Dict{String,Int}()
    linearized = Set{String}()

    for (raw_element_id, connectivity) in sort(
        collect(pairs(elements));
        by=first,
    )
        element_id = Int(raw_element_id)
        raw_topology = get(element_types, raw_element_id, nothing)
        raw_topology === nothing && begin
            increment_surface_count!(unsupported, "missing")
            continue
        end
        topology = surface_topology(raw_topology)
        boundary = element_boundary(topology)
        boundary.linearized && push!(linearized, string(topology))

        if boundary.kind === :volume_faces
            face_positions = boundary.faces
            corner_count = maximum(maximum, face_positions)
            corner_count <= length(connectivity) || throw(ArgumentError(
                "element $element_id has too few nodes for $topology",
            ))
            element_nodes = [Int(connectivity[index]) for index in 1:corner_count]

            for positions in face_positions
                face_nodes = surface_local_nodes(connectivity, positions, element_id)
                face_nodes = orient_surface_outward(nodes, face_nodes, element_nodes)
                key = Tuple(sort(face_nodes))
                face_counts[key] = get(face_counts, key, 0) + 1
                get!(face_records, key) do
                    SurfaceFace(face_nodes, element_id, topology)
                end
            end
        elseif boundary.kind === :surface_face
            face_nodes = surface_local_nodes(
                connectivity,
                only(boundary.faces),
                element_id,
            )
            push!(surface_faces, SurfaceFace(face_nodes, element_id, topology))
        elseif boundary.kind === :non_surface
            increment_surface_count!(skipped, topology)
        else
            increment_surface_count!(unsupported, topology)
        end
    end

    volume_faces = SurfaceFace[]
    nonmanifold_count = 0
    for key in sort!(collect(keys(face_records)))
        count = face_counts[key]
        if count == 1
            push!(volume_faces, face_records[key])
        elseif count > 2
            nonmanifold_count += 1
        end
    end

    triangles = SurfaceTriangle[]
    for face in vcat(volume_faces, surface_faces)
        append!(triangles, triangulate_surface_face(
            nodes,
            face.nodes,
            face.element_id,
            face.topology,
        ))
    end

    return (
        triangles=triangles,
        volume_boundary_face_count=length(volume_faces),
        surface_element_face_count=length(surface_faces),
        nonmanifold_face_count=nonmanifold_count,
        unsupported_topologies=unsupported,
        skipped_topologies=skipped,
        linearized_topologies=sort!(collect(linearized)),
    )
end
