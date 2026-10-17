# Minimal Abaqus INP mesh writer

"""
Valid face identifiers for Abaqus element topologies.
"""
const VALID_TOPOLOGY_FACES = Dict{Symbol,Set{Symbol}}(
    :Tet4    => Set([:S1, :S2, :S3, :S4]),
    :Tet10   => Set([:S1, :S2, :S3, :S4]),
    :Hex8    => Set([:S1, :S2, :S3, :S4, :S5, :S6]),
    :Hex20   => Set([:S1, :S2, :S3, :S4, :S5, :S6]),
    :Wedge6  => Set([:S1, :S2, :S3, :S4, :S5]),
    :Wedge15 => Set([:S1, :S2, :S3, :S4, :S5]),
    :Tri3    => Set([:S1, :S2, :S3, :SPOS, :SNEG]),
    :Tri6    => Set([:S1, :S2, :S3, :SPOS, :SNEG]),
    :Quad4   => Set([:S1, :S2, :S3, :S4, :SPOS, :SNEG]),
    :Quad8   => Set([:S1, :S2, :S3, :S4, :SPOS, :SNEG]),
    :Quad9   => Set([:S1, :S2, :S3, :S4, :SPOS, :SNEG]),
    :Seg2    => Set([:S1, :S2]),
    :Seg3    => Set([:S1, :S2]),
)

function _get_mesh_field(mesh::AbstractDict, key::String, default=nothing)
    if haskey(mesh, key)
        return mesh[key]
    elseif haskey(mesh, Symbol(key))
        return mesh[Symbol(key)]
    else
        return default
    end
end

function _parse_int_id(val, context::AbstractString)
    if val isa Integer
        return Int(val)
    elseif val isa AbstractString
        parsed = tryparse(Int, strip(val))
        parsed !== nothing && return parsed
    end
    throw(ArgumentError("$context must be an integer, got $val"))
end

function _format_coord(c::Real)
    val = Float64(c)
    isfinite(val) || throw(ArgumentError("node coordinate must be finite, got $c"))
    return iszero(val) ? "0.0" : string(val)
end

function _extract_surface_pair(item, surf_name::AbstractString)
    if item isa Pair
        return item.first, item.second
    elseif item isa Tuple || item isa AbstractVector
        length(item) == 2 || throw(ArgumentError(
            "surface \"$surf_name\" entry must be a 2-tuple (element_id, face_id), got $item"
        ))
        return item[1], item[2]
    else
        throw(ArgumentError(
            "surface \"$surf_name\" has invalid entry format: $item"
        ))
    end
end

function _write_id_chunks(io::IO, ids::Vector{Int}; per_line::Int=16)
    for i in 1:per_line:length(ids)
        chunk = ids[i:min(i + per_line - 1, length(ids))]
        println(io, join(chunk, ", "))
    end
end

"""
    abaqus_mesh_string(mesh::AbstractDict; kwargs...) -> String

Serialize a mesh dictionary into an Abaqus `.inp` format string.

See [`abaqus_write_mesh`](@ref) for full details on dictionary schema,
options, and validation.
"""
function abaqus_mesh_string(mesh::AbstractDict; kwargs...)
    io = IOBuffer()
    abaqus_write_mesh(io, mesh; kwargs...)
    return String(take!(io))
end

"""
    abaqus_write_mesh(filename::AbstractString, mesh::AbstractDict; kwargs...)
    abaqus_write_mesh(io::IO, mesh::AbstractDict; kwargs...)

Write a mesh dictionary to an Abaqus `.inp` format file or IO stream.

Serializes `*NODE`, `*ELEMENT`, `*NSET`, `*ELSET`, and `*SURFACE, TYPE=ELEMENT`
keywords in deterministic order with full binary64 floating-point precision.
Output is suitable for inclusion in larger Abaqus models via `*INCLUDE`.

# Arguments
- `io` or `filename`: Output destination (`IO` stream or file path)
- `mesh`: Dictionary matching the `abaqus_read_mesh` schema:
  - `"nodes"`: Node ID → coordinates [x, y, z] (or 2D [x, y])
  - `"elements"`: Element ID → node connectivity
  - `"element_codes"`: (Optional if `element_code` is passed) Element ID → Abaqus element code (e.g., `:DC3D6`, `:C3D8`)
  - `"element_types"`: (Optional) Element ID → topology type (e.g., `:Wedge6`, `:Hex8`)
  - `"node_sets"`: (Optional) Set name → vector of node IDs
  - `"element_sets"`: (Optional) Set name → vector of element IDs
  - `"surface_sets"`: (Optional) Surface name → vector of (element_id, face_id) pairs
  - `"surface_types"`: (Optional) Surface name → surface type (must be `:ELEMENT`)

# Keyword Arguments
- `element_code`: Default Abaqus element code symbol (e.g., `:DC3D6`, `:C3D6`) applied to elements without an explicit code in `mesh["element_codes"]`.
- `element_codes`: Dictionary mapping element ID to element code symbol.
- `comments`: Optional comment string or vector of comment strings emitted with `**` prefix.
- `validate`: Validate IDs, coordinates, connectivity, element codes, sets, and surface face topology (default: `true`).

# Examples
```julia
using AbaqusReader

mesh = Dict(
    "nodes" => Dict(
        1 => [0.0, 0.0, 0.0],
        2 => [1.0, 0.0, 0.0],
        3 => [0.0, 1.0, 0.0],
        4 => [0.0, 0.0, 1.0],
        5 => [1.0, 0.0, 1.0],
        6 => [0.0, 1.0, 1.0],
    ),
    "elements" => Dict(1 => [1, 2, 3, 4, 5, 6]),
    "element_codes" => Dict(1 => :DC3D6),
    "surface_sets" => Dict(
        "INNER" => [(1, :S1)],
        "OUTER" => [(1, :S2)],
    ),
)

abaqus_write_mesh("mesh.inp", mesh)
```
"""
function abaqus_write_mesh(filename::AbstractString, mesh::AbstractDict; kwargs...)
    open(filename, "w") do io
        abaqus_write_mesh(io, mesh; kwargs...)
    end
    return filename
end

function abaqus_write_mesh(io::IO, mesh::AbstractDict;
    element_code::Union{Symbol,AbstractString,Nothing}=nothing,
    element_codes::Union{AbstractDict,Nothing}=nothing,
    comments::Union{AbstractVector{<:AbstractString},AbstractString,Nothing}=nothing,
    validate::Bool=true,
)
    # 1. Extract nodes
    raw_nodes = _get_mesh_field(mesh, "nodes")
    (raw_nodes === nothing || isempty(raw_nodes)) && throw(ArgumentError(
        "mesh must contain at least one node in \"nodes\""
    ))

    nodes = Dict{Int,Vector{Float64}}()
    for (raw_nid, coords) in raw_nodes
        nid = _parse_int_id(raw_nid, "node ID")
        nid > 0 || throw(ArgumentError("node ID must be positive: $nid"))
        (coords isa AbstractVector || coords isa Tuple) || throw(ArgumentError(
            "node coordinates for node $nid must be a vector or tuple"
        ))
        dim = length(coords)
        1 <= dim <= 3 || throw(ArgumentError(
            "node coordinates for node $nid must have dimension 1, 2, or 3, got $dim"
        ))
        float_coords = Float64[]
        for c in coords
            c isa Real || throw(ArgumentError(
                "node $nid coordinate is not a real number: $c"
            ))
            val = Float64(c)
            isfinite(val) || throw(ArgumentError(
                "node $nid coordinate must be finite, got $c"
            ))
            push!(float_coords, val)
        end
        nodes[nid] = float_coords
    end

    # 2. Extract elements
    raw_elements = _get_mesh_field(mesh, "elements")
    (raw_elements === nothing || isempty(raw_elements)) && throw(ArgumentError(
        "mesh must contain at least one element in \"elements\""
    ))

    elements = Dict{Int,Vector{Int}}()
    for (raw_eid, raw_conn) in raw_elements
        eid = _parse_int_id(raw_eid, "element ID")
        eid > 0 || throw(ArgumentError("element ID must be positive: $eid"))
        (raw_conn isa AbstractVector || raw_conn isa Tuple) || throw(ArgumentError(
            "element connectivity for element $eid must be a vector or tuple"
        ))
        !isempty(raw_conn) || throw(ArgumentError(
            "element connectivity for element $eid cannot be empty"
        ))
        conn = Int[]
        for raw_nid in raw_conn
            nid = _parse_int_id(raw_nid, "connectivity node ID in element $eid")
            nid > 0 || throw(ArgumentError(
                "connectivity node ID in element $eid must be positive: $nid"
            ))
            if validate
                haskey(nodes, nid) || throw(ArgumentError(
                    "element $eid references node $nid, which is not in \"nodes\""
                ))
            end
            push!(conn, nid)
        end
        elements[eid] = conn
    end

    # 3. Resolve element codes and validate formulations
    raw_element_codes = _get_mesh_field(mesh, "element_codes")
    raw_element_types = _get_mesh_field(mesh, "element_types")

    element_codes_map = Dict{Int,Symbol}()
    for eid in keys(elements)
        code = nothing
        if element_codes !== nothing && (haskey(element_codes, eid) || haskey(element_codes, string(eid)))
            code = haskey(element_codes, eid) ? element_codes[eid] : element_codes[string(eid)]
        elseif raw_element_codes !== nothing && (haskey(raw_element_codes, eid) || haskey(raw_element_codes, string(eid)))
            code = haskey(raw_element_codes, eid) ? raw_element_codes[eid] : raw_element_codes[string(eid)]
        elseif element_code !== nothing
            code = element_code
        end

        code === nothing && throw(ArgumentError(
            "element $eid has no Abaqus element code specified. " *
            "Abaqus element formulation cannot be inferred solely from topology; " *
            "specify element_code or provide \"element_codes\"."
        ))

        code_sym = Symbol(uppercase(string(code)))

        if validate
            haskey(ELEMENT_INFO, code_sym) || throw(ArgumentError(
                "unknown Abaqus element code: $code_sym for element $eid"
            ))
            expected_nodes, topo = ELEMENT_INFO[code_sym]
            conn_len = length(elements[eid])
            conn_len == expected_nodes || throw(ArgumentError(
                "element $eid has $conn_len nodes, but code $code_sym requires $expected_nodes nodes"
            ))

            if raw_element_types !== nothing
                has_type = haskey(raw_element_types, eid) || haskey(raw_element_types, string(eid))
                if has_type
                    raw_type = haskey(raw_element_types, eid) ? raw_element_types[eid] : raw_element_types[string(eid)]
                    type_sym = Symbol(raw_type)
                    if type_sym === :wedge18 || type_sym === :Wedge18
                        throw(ArgumentError(
                            "18-node wedge (:wedge18) is not supported by Abaqus (Abaqus quadratic wedge requires 15 nodes, e.g. C3D15/DC3D15)"
                        ))
                    end
                    topo === type_sym || throw(ArgumentError(
                        "element $eid with code $code_sym has topology $topo, but element_types specifies $type_sym"
                    ))
                end
            end
        end

        element_codes_map[eid] = code_sym
    end

    # 4. Extract and validate node sets
    raw_node_sets = _get_mesh_field(mesh, "node_sets")
    node_sets = Dict{String,Vector{Int}}()
    if raw_node_sets !== nothing
        for (raw_name, raw_ids) in raw_node_sets
            sname = strip(string(raw_name))
            !isempty(sname) || throw(ArgumentError("node set name cannot be empty"))
            !isempty(raw_ids) || throw(ArgumentError("node set \"$sname\" cannot be empty"))
            set_ids = Int[]
            for raw_id in raw_ids
                nid = _parse_int_id(raw_id, "node ID in set \"$sname\"")
                if validate
                    haskey(nodes, nid) || throw(ArgumentError(
                        "node set \"$sname\" references node $nid, which is not in \"nodes\""
                    ))
                end
                push!(set_ids, nid)
            end
            node_sets[sname] = sort(unique(set_ids))
        end
    end

    # 5. Extract and validate element sets
    raw_element_sets = _get_mesh_field(mesh, "element_sets")
    element_sets = Dict{String,Vector{Int}}()
    if raw_element_sets !== nothing
        for (raw_name, raw_ids) in raw_element_sets
            sname = strip(string(raw_name))
            !isempty(sname) || throw(ArgumentError("element set name cannot be empty"))
            !isempty(raw_ids) || throw(ArgumentError("element set \"$sname\" cannot be empty"))
            set_ids = Int[]
            for raw_id in raw_ids
                eid = _parse_int_id(raw_id, "element ID in set \"$sname\"")
                if validate
                    haskey(elements, eid) || throw(ArgumentError(
                        "element set \"$sname\" references element $eid, which is not in \"elements\""
                    ))
                end
                push!(set_ids, eid)
            end
            element_sets[sname] = sort(unique(set_ids))
        end
    end

    # 6. Extract and validate surfaces
    raw_surface_sets = _get_mesh_field(mesh, "surface_sets")
    raw_surface_types = _get_mesh_field(mesh, "surface_types")
    surface_sets = Dict{String,Vector{Tuple{Int,Symbol}}}()
    if raw_surface_sets !== nothing
        for (raw_name, entries) in raw_surface_sets
            sname = strip(string(raw_name))
            !isempty(sname) || throw(ArgumentError("surface name cannot be empty"))
            !isempty(entries) || throw(ArgumentError("surface \"$sname\" cannot be empty"))

            if validate && raw_surface_types !== nothing
                has_stype = haskey(raw_surface_types, sname) || haskey(raw_surface_types, raw_name)
                if has_stype
                    raw_stype = haskey(raw_surface_types, sname) ? raw_surface_types[sname] : raw_surface_types[raw_name]
                    stype_sym = Symbol(uppercase(string(raw_stype)))
                    stype_sym === :ELEMENT || throw(ArgumentError(
                        "surface \"$sname\" has unsupported surface type: $stype_sym (only :ELEMENT is supported)"
                    ))
                end
            end

            pairs = Tuple{Int,Symbol}[]
            for item in entries
                raw_eid, raw_face = _extract_surface_pair(item, sname)
                eid = _parse_int_id(raw_eid, "element ID in surface \"$sname\"")
                if validate
                    haskey(elements, eid) || throw(ArgumentError(
                        "surface \"$sname\" references element $eid, which is not in \"elements\""
                    ))
                    code_sym = element_codes_map[eid]
                    _, topo = ELEMENT_INFO[code_sym]
                    face_sym = Symbol(uppercase(string(raw_face)))
                    if haskey(VALID_TOPOLOGY_FACES, topo)
                        face_sym in VALID_TOPOLOGY_FACES[topo] || throw(ArgumentError(
                            "surface \"$sname\" specifies invalid face $face_sym for element $eid with topology $topo"
                        ))
                    end
                    push!(pairs, (eid, face_sym))
                else
                    face_sym = Symbol(uppercase(string(raw_face)))
                    push!(pairs, (eid, face_sym))
                end
            end
            # Deterministic sorting of surface pairs
            sort!(pairs, by=p -> (p[1], string(p[2])))
            surface_sets[sname] = pairs
        end
    end

    # =========================================================================
    # Write output deterministically
    # =========================================================================

    # Optional comments
    if comments !== nothing
        if comments isa AbstractString
            for line in split(comments, '\n')
                println(io, "** ", line)
            end
        else
            for line in comments
                println(io, "** ", line)
            end
        end
    end

    # *NODE
    println(io, "*NODE")
    for nid in sort(collect(keys(nodes)))
        coords = nodes[nid]
        formatted = [_format_coord(c) for c in coords]
        println(io, join(vcat(string(nid), formatted), ", "))
    end

    # *ELEMENT, TYPE=<code>
    # Group elements by element code
    code_groups = Dict{Symbol,Vector{Int}}()
    for (eid, code_sym) in element_codes_map
        push!(get!(code_groups, code_sym, Int[]), eid)
    end

    for code_sym in sort(collect(keys(code_groups)); by=string)
        println(io, "*ELEMENT, TYPE=$code_sym")
        eids = sort(code_groups[code_sym])
        for eid in eids
            conn = elements[eid]
            if length(conn) <= 15
                println(io, join(vcat(eid, conn), ", "))
            else
                println(io, join(vcat(eid, conn[1:15]), ", ") * ",")
                println(io, join(conn[16:end], ", "))
            end
        end
    end

    # *NSET, NSET=<name>
    for sname in sort(collect(keys(node_sets)))
        println(io, "*NSET, NSET=$sname")
        _write_id_chunks(io, node_sets[sname])
    end

    # *ELSET, ELSET=<name>
    for sname in sort(collect(keys(element_sets)))
        println(io, "*ELSET, ELSET=$sname")
        _write_id_chunks(io, element_sets[sname])
    end

    # *SURFACE, TYPE=ELEMENT, NAME=<name>
    for sname in sort(collect(keys(surface_sets)))
        println(io, "*SURFACE, TYPE=ELEMENT, NAME=$sname")
        for (eid, face) in surface_sets[sname]
            println(io, "$eid, $face")
        end
    end

    return nothing
end
