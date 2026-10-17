# Minimal Abaqus INP mesh writer

"""
Maximum allowable node and element ID in Abaqus (up to 9 digits).
"""
const MAX_ABAQUS_ID = 999_999_999

"""
Regex pattern for valid unquoted Abaqus label names:
Begins with an ASCII letter, followed by up to 79 ASCII alphanumeric,
underscore, or hyphen characters (max 80 characters total).
"""
const ABAQUS_NAME_REGEX = r"^[A-Za-z][A-Za-z0-9_-]{0,79}$"

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
    id = if val isa Integer
        Int(val)
    elseif val isa AbstractString
        parsed = tryparse(Int, strip(val))
        parsed !== nothing ? parsed : nothing
    else
        nothing
    end
    id === nothing && throw(ArgumentError("$context must be an integer, got $val"))
    1 <= id <= MAX_ABAQUS_ID || throw(ArgumentError(
        "$context must be between 1 and $MAX_ABAQUS_ID, got $id"
    ))
    return id
end

function _validate_abaqus_name(raw_name, context::AbstractString)
    name_str = string(raw_name)
    strip(name_str) == name_str || throw(ArgumentError(
        "$context \"$name_str\" must not contain leading or trailing whitespace"
    ))
    !isempty(name_str) || throw(ArgumentError("$context name cannot be empty"))
    length(name_str) <= 80 || throw(ArgumentError(
        "$context \"$name_str\" exceeds maximum length of 80 characters ($(length(name_str)) > 80)"
    ))
    occursin(ABAQUS_NAME_REGEX, name_str) || throw(ArgumentError(
        "$context \"$name_str\" is not a valid Abaqus name: must begin with an ASCII letter and contain only alphanumeric characters, underscores, or hyphens (max 80 chars; no spaces, commas, periods, equals, or control characters)"
    ))
    return name_str
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

function _write_element_line(io::IO, eid::Int, conn::Vector{Int})
    if length(conn) <= 15
        println(io, join(vcat(eid, conn), ", "))
    else
        println(io, join(vcat(eid, conn[1:15]), ", ") * ",")
        rem = conn[16:end]
        while length(rem) > 16
            println(io, join(rem[1:16], ", ") * ",")
            rem = rem[17:end]
        end
        println(io, join(rem, ", "))
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
  - `"nodes"`: Node ID → coordinates [x, y, z] (or 2D [x, y]) (ID range: `1` to `999,999,999`)
  - `"elements"`: Element ID → node connectivity (ID range: `1` to `999,999,999`)
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
- `validate`: Validate IDs, bounds, coordinates, connectivity, element codes, sets, and surface face topology (default: `true`).

# Abaqus Name and ID Rules
- Node and element labels must be positive integers between `1` and `999,999,999`.
- Set and surface names must be 1 to 80 ASCII characters, beginning with a letter and containing only letters, numbers, underscores, and hyphens. Case-insensitive collisions within the same dictionary are rejected.
- Element-based surface faces must be valid for the element's topology (e.g. `:S1` through `:S5` for `:Wedge6`). Elements with topologies that do not define element-based surface faces (e.g. `:Poi1`) fail closed when `validate=true`.

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
        haskey(nodes, nid) && throw(ArgumentError(
            "duplicate node ID after normalization: $nid (conflicting raw keys in \"nodes\")"
        ))
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
        haskey(elements, eid) && throw(ArgumentError(
            "duplicate element ID after normalization: $eid (conflicting raw keys in \"elements\")"
        ))
        (raw_conn isa AbstractVector || raw_conn isa Tuple) || throw(ArgumentError(
            "element connectivity for element $eid must be a vector or tuple"
        ))
        !isempty(raw_conn) || throw(ArgumentError(
            "element connectivity for element $eid cannot be empty"
        ))
        conn = Int[]
        for raw_nid in raw_conn
            nid = _parse_int_id(raw_nid, "connectivity node ID in element $eid")
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

    parsed_element_codes = Dict{Int,Symbol}()
    if raw_element_codes !== nothing
        for (raw_eid, raw_code) in raw_element_codes
            eid = _parse_int_id(raw_eid, "element ID in \"element_codes\"")
            haskey(parsed_element_codes, eid) && throw(ArgumentError(
                "duplicate element ID in \"element_codes\" after normalization: $eid"
            ))
            parsed_element_codes[eid] = Symbol(uppercase(string(raw_code)))
        end
    end

    kw_element_codes = Dict{Int,Symbol}()
    if element_codes !== nothing
        for (raw_eid, raw_code) in element_codes
            eid = _parse_int_id(raw_eid, "element ID in element_codes keyword argument")
            haskey(kw_element_codes, eid) && throw(ArgumentError(
                "duplicate element ID in element_codes keyword argument after normalization: $eid"
            ))
            kw_element_codes[eid] = Symbol(uppercase(string(raw_code)))
        end
    end

    parsed_element_types = Dict{Int,Symbol}()
    if raw_element_types !== nothing
        for (raw_eid, raw_type) in raw_element_types
            eid = _parse_int_id(raw_eid, "element ID in \"element_types\"")
            haskey(parsed_element_types, eid) && throw(ArgumentError(
                "duplicate element ID in \"element_types\" after normalization: $eid"
            ))
            parsed_element_types[eid] = Symbol(raw_type)
        end
    end

    element_codes_map = Dict{Int,Symbol}()
    for eid in keys(elements)
        code = nothing
        if haskey(kw_element_codes, eid)
            code = kw_element_codes[eid]
        elseif haskey(parsed_element_codes, eid)
            code = parsed_element_codes[eid]
        elseif element_code !== nothing
            code = Symbol(uppercase(string(element_code)))
        end

        code === nothing && throw(ArgumentError(
            "element $eid has no Abaqus element code specified. " *
            "Abaqus element formulation cannot be inferred solely from topology; " *
            "specify element_code or provide \"element_codes\"."
        ))

        code_sym = code

        if validate
            haskey(ELEMENT_INFO, code_sym) || throw(ArgumentError(
                "unknown Abaqus element code: $code_sym for element $eid"
            ))
            expected_nodes, topo = ELEMENT_INFO[code_sym]

            if haskey(parsed_element_types, eid)
                type_sym = parsed_element_types[eid]
                if type_sym === :wedge18 || type_sym === :Wedge18
                    throw(ArgumentError(
                        "18-node wedge (:wedge18) is not supported by Abaqus (Abaqus quadratic wedge requires 15 nodes, e.g. C3D15/DC3D15)"
                    ))
                end
                topo === type_sym || throw(ArgumentError(
                    "element $eid with code $code_sym has topology $topo, but element_types specifies $type_sym"
                ))
            end

            conn_len = length(elements[eid])
            conn_len == expected_nodes || throw(ArgumentError(
                "element $eid has $conn_len nodes, but code $code_sym requires $expected_nodes nodes"
            ))
        end

        element_codes_map[eid] = code_sym
    end

    # 4. Extract and validate node sets
    raw_node_sets = _get_mesh_field(mesh, "node_sets")
    node_sets = Dict{String,Vector{Int}}()
    if raw_node_sets !== nothing
        seen_nsets = Dict{String,String}()
        for (raw_name, raw_ids) in raw_node_sets
            sname = _validate_abaqus_name(raw_name, "node set")
            norm_name = uppercase(sname)
            if haskey(seen_nsets, norm_name)
                throw(ArgumentError(
                    "duplicate node set name under case-insensitive normalization: \"$sname\" conflicts with \"$(seen_nsets[norm_name])\""
                ))
            end
            seen_nsets[norm_name] = sname
            (raw_ids isa AbstractVector || raw_ids isa Tuple) || throw(ArgumentError(
                "node set \"$sname\" must be a vector or tuple of node IDs"
            ))
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
        seen_elsets = Dict{String,String}()
        for (raw_name, raw_ids) in raw_element_sets
            sname = _validate_abaqus_name(raw_name, "element set")
            norm_name = uppercase(sname)
            if haskey(seen_elsets, norm_name)
                throw(ArgumentError(
                    "duplicate element set name under case-insensitive normalization: \"$sname\" conflicts with \"$(seen_elsets[norm_name])\""
                ))
            end
            seen_elsets[norm_name] = sname
            (raw_ids isa AbstractVector || raw_ids isa Tuple) || throw(ArgumentError(
                "element set \"$sname\" must be a vector or tuple of element IDs"
            ))
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
        seen_surfs = Dict{String,String}()
        for (raw_name, entries) in raw_surface_sets
            sname = _validate_abaqus_name(raw_name, "surface")
            norm_name = uppercase(sname)
            if haskey(seen_surfs, norm_name)
                throw(ArgumentError(
                    "duplicate surface name under case-insensitive normalization: \"$sname\" conflicts with \"$(seen_surfs[norm_name])\""
                ))
            end
            seen_surfs[norm_name] = sname
            (entries isa AbstractVector || entries isa Tuple) || throw(ArgumentError(
                "surface \"$sname\" must be a vector or tuple of (element_id, face_id) entries"
            ))
            !isempty(entries) || throw(ArgumentError("surface \"$sname\" cannot be empty"))

            if validate && raw_surface_types !== nothing
                stype_val = nothing
                for (k, v) in raw_surface_types
                    if uppercase(string(k)) == norm_name
                        stype_val = v
                        break
                    end
                end
                if stype_val !== nothing
                    stype_sym = Symbol(uppercase(string(stype_val)))
                    stype_sym === :ELEMENT || throw(ArgumentError(
                        "surface \"$sname\" has unsupported surface type: $stype_sym (only :ELEMENT is supported)"
                    ))
                end
            end

            pairs = Tuple{Int,Symbol}[]
            for item in entries
                raw_eid, raw_face = _extract_surface_pair(item, sname)
                eid = _parse_int_id(raw_eid, "element ID in surface \"$sname\"")
                face_sym = Symbol(uppercase(string(raw_face)))
                if validate
                    haskey(elements, eid) || throw(ArgumentError(
                        "surface \"$sname\" references element $eid, which is not in \"elements\""
                    ))
                    code_sym = element_codes_map[eid]
                    _, topo = ELEMENT_INFO[code_sym]
                    haskey(VALID_TOPOLOGY_FACES, topo) || throw(ArgumentError(
                        "element $eid in surface \"$sname\" has topology $topo, which does not support element-based surfaces"
                    ))
                    face_sym in VALID_TOPOLOGY_FACES[topo] || throw(ArgumentError(
                        "surface \"$sname\" specifies invalid face $face_sym for element $eid with topology $topo"
                    ))
                end
                push!(pairs, (eid, face_sym))
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
    code_groups = Dict{Symbol,Vector{Int}}()
    for (eid, code_sym) in element_codes_map
        push!(get!(code_groups, code_sym, Int[]), eid)
    end

    for code_sym in sort(collect(keys(code_groups)); by=string)
        println(io, "*ELEMENT, TYPE=$code_sym")
        eids = sort(code_groups[code_sym])
        for eid in eids
            conn = elements[eid]
            _write_element_line(io, eid, conn)
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
