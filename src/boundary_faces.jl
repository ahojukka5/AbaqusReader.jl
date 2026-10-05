# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

"""
    boundary_faces(mesh::AbstractDict)

Corner faces of one mesh from [`abaqus_read_mesh`](@ref) or
[`abaqus_parse_mesh`](@ref), classified with [`element_boundary`](@ref).

Volume topologies (`kind == :volume_faces`) are grouped by the sorted set of
corner-node ids. A set owned by one element is an exterior face and is
returned. A set owned by two elements is a shared interior face and is
omitted. A set owned by more than two elements is non-manifold: it is
omitted and counted in `nonmanifold_face_count`. An exterior face records
the only element that owns that node set. `nodes` are that element's
side-table corner order. This function does not look at coordinates and
does not flip that order to point away from the element.

Triangular and quadrilateral elements (`kind == :surface_face`) each
contribute their single corner face, including when another element uses the
same nodes. Those faces are not matched to volume faces. Point and line
topologies are counted in `skipped_topologies` and omitted. Any other
topology, and an element with no type, is counted in
`unsupported_topologies` and omitted. A missing type is the key `"missing"`.

Exterior faces are listed in lexicographic order of their sorted node-id
keys. Explicit surface faces follow, in ascending element-id order.
Quadrilateral faces are returned whole; they are not split into triangles.

The named tuple fields are:

- `faces`: each item has `nodes::Vector{Int}`, `element_id::Int`,
  `topology::Symbol`, and `from_volume::Bool`
- `volume_boundary_face_count`
- `surface_element_face_count`
- `nonmanifold_face_count`
- `unsupported_topologies::Dict{String,Int}`
- `skipped_topologies::Dict{String,Int}`
- `linearized_topologies::Vector{String}`, sorted names of topologies whose
  boundary dropped midside or center nodes

Throws `ArgumentError` when an element's connectivity is shorter than the
corner indices of its topology. A connectivity entry whose node is absent
from `mesh["nodes"]` is not an error here.
"""
function boundary_faces(mesh::AbstractDict)
    elements = get(mesh, "elements", Dict())
    element_types = get(mesh, "element_types", Dict())

    face_records = Dict{Tuple,NamedTuple}()
    face_counts = Dict{Tuple,Int}()
    surface_faces = NamedTuple[]
    unsupported = Dict{String,Int}()
    skipped = Dict{String,Int}()
    linearized = Set{String}()

    for (raw_element_id, connectivity) in sort(collect(pairs(elements)); by=first)
        element_id = Int(raw_element_id)
        raw_topology = get(element_types, raw_element_id, nothing)
        raw_topology === nothing && begin
            _boundary_count!(unsupported, "missing")
            continue
        end
        topology = raw_topology isa Symbol ? raw_topology : Symbol(raw_topology)
        boundary = element_boundary(topology)
        boundary.linearized && push!(linearized, string(topology))

        if boundary.kind === :volume_faces
            face_positions = boundary.faces
            corner_count = maximum(maximum, face_positions)
            corner_count <= length(connectivity) || throw(ArgumentError(
                "element $element_id has too few nodes for $topology",
            ))
            for positions in face_positions
                face_nodes = _boundary_nodes(connectivity, positions, element_id)
                key = Tuple(sort(face_nodes))
                face_counts[key] = get(face_counts, key, 0) + 1
                get!(face_records, key) do
                    (
                        nodes=face_nodes,
                        element_id=element_id,
                        topology=topology,
                        from_volume=true,
                    )
                end
            end
        elseif boundary.kind === :surface_face
            face_nodes = _boundary_nodes(
                connectivity,
                only(boundary.faces),
                element_id,
            )
            push!(surface_faces, (
                nodes=face_nodes,
                element_id=element_id,
                topology=topology,
                from_volume=false,
            ))
        elseif boundary.kind === :non_surface
            _boundary_count!(skipped, topology)
        else
            _boundary_count!(unsupported, topology)
        end
    end

    volume_faces = NamedTuple[]
    nonmanifold_count = 0
    for key in sort!(collect(keys(face_records)))
        count = face_counts[key]
        if count == 1
            push!(volume_faces, face_records[key])
        elseif count > 2
            nonmanifold_count += 1
        end
    end

    return (
        faces=vcat(volume_faces, surface_faces),
        volume_boundary_face_count=length(volume_faces),
        surface_element_face_count=length(surface_faces),
        nonmanifold_face_count=nonmanifold_count,
        unsupported_topologies=unsupported,
        skipped_topologies=skipped,
        linearized_topologies=sort!(collect(linearized)),
    )
end

function _boundary_nodes(connectivity, positions, element_id::Int)
    maximum(positions) <= length(connectivity) || throw(ArgumentError(
        "element $element_id has too few nodes for its topology",
    ))
    return [Int(connectivity[position]) for position in positions]
end

function _boundary_count!(counts::Dict{String,Int}, key)
    name = string(key)
    counts[name] = get(counts, name, 0) + 1
    return counts
end
