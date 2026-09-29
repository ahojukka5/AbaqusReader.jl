# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

"""
    abaqus_parse_mesh(content::AbstractString) -> Dict

Parse ABAQUS mesh from a string buffer.

This is the core parsing function that extracts mesh geometry and topology from
ABAQUS input file content provided as a string. Use this when you have the content
in memory or want to avoid file I/O in tests.

# Arguments
- `content::AbstractString`: ABAQUS input file content as a string

# Returns
Same dictionary structure as `abaqus_read_mesh`:
- `"nodes"`: Node coordinates
- `"elements"`: Element connectivity
- `"element_types"`: Topological types
- `"element_codes"`: Original ABAQUS element names
- `"node_sets"`, `"element_sets"`, `"surface_sets"`: Named sets

# Examples
```julia
inp_content = \"\"\"
*NODE
1, 0.0, 0.0, 0.0
2, 1.0, 0.0, 0.0
*ELEMENT, TYPE=C3D8
1, 1, 2, 3, 4, 5, 6, 7, 8
\"\"\"

mesh = abaqus_parse_mesh(inp_content)
```

# See Also
- [`abaqus_read_mesh`](@ref): Read mesh from file
"""
function abaqus_parse_mesh(content::AbstractString; kwargs...)
    for line in split(content, '\n')
        include_keyword(line) && throw(ArgumentError(
            "*INCLUDE requires a file path; use abaqus_read_mesh",
        ))
    end
    verbose = get(kwargs, :verbose, true)

    # Detect if this is a modern PART/ASSEMBLY format
    lines = split(content, '\n')
    if detect_assembly_format(collect(lines))
        @debug "Detected PART/ASSEMBLY format, using assembly parser"
        io = IOBuffer(content)
        return parse_assembly_mesh(io; verbose=verbose)
    else
        @debug "Using flat parser"
        io = IOBuffer(content)
        return parse_abaqus(io, verbose)
    end
end

"""
    abaqus_read_mesh(fn::String) -> Dict

Read ABAQUS `.inp` file and extract mesh geometry and topology.

This function performs **mesh-only parsing**, extracting nodes, elements, sets, and surfaces
without parsing materials, boundary conditions, or analysis steps. Use this when you only need
the geometric structure of the model.

# Arguments
- `fn::String`: Path to the ABAQUS input file (`.inp`)

# Returns
A `Dict{String, Any}` containing:
- `"nodes"`: `Dict{Int, Vector{Float64}}` - Node ID → coordinates [x, y, z]
- `"elements"`: `Dict{Int, Vector{Int}}` - Element ID → node connectivity
- `"element_types"`: `Dict{Int, Symbol}` - Element ID → topological type (e.g., `:Tet4`, `:Hex8`)
- `"element_codes"`: `Dict{Int, Symbol}` - Element ID → original ABAQUS element name (e.g., `:C3D8R`, `:CPS3`)
- `"node_sets"`: `Dict{String, Vector{Int}}` - Node set name → node IDs
- `"element_sets"`: `Dict{String, Vector{Int}}` - Element set name → element IDs
- `"surface_sets"`: `Dict{String, Vector{Tuple{Int, Symbol}}}` - Surface name → (element, face) pairs
- `"surface_types"`: `Dict{String, Symbol}` - Surface name → surface type (e.g., `:ELEMENT`)

# Examples
```julia
using AbaqusReader

# Read mesh from file
mesh = abaqus_read_mesh("model.inp")

# Access node coordinates
coords = mesh["nodes"][1]  # [x, y, z] for node 1

# Get element connectivity
elem_nodes = mesh["elements"][1]  # Node IDs for element 1

# Get topological element type
elem_type = mesh["element_types"][1]  # e.g., :Hex8

# Get original ABAQUS element code
elem_code = mesh["element_codes"][1]  # e.g., :C3D8R

# Get nodes in a set
boundary_nodes = mesh["node_sets"]["BOUNDARY"]
```

# See Also
- [`abaqus_parse_mesh`](@ref): Parse mesh from string buffer
- [`abaqus_read_model`](@ref): Read complete model including materials and boundary conditions
- [`create_surface_elements`](@ref): Extract surface elements from surface definitions

# Notes
- Supports 60+ ABAQUS element types (see documentation for full list)
- Returns simple dictionary structure for easy manipulation
- Much faster than `abaqus_read_model` when only mesh is needed
- Element types are mapped to generic topology (e.g., `C3D8R` → `:Hex8`)
- Original ABAQUS element names preserved in `element_codes` for traceability
- `*INCLUDE, INPUT=` is read relative to the parent file, with a cycle guard and a nesting cap of 16
"""
const INCLUDE_DEPTH_CAP = 16

function include_keyword(line::AbstractString)
    stripped = strip(line)
    startswith(stripped, "**") && return false
    upper = uppercase(stripped)
    startswith(upper, "*INCLUDE") || return false
    rest = chop(upper; head=length("*INCLUDE"), tail=0)
    return isempty(rest) || startswith(rest, ",") || startswith(rest, " ")
end

function include_input_path(line::AbstractString)
    match_result = match(r"INPUT\s*=\s*(?:\"([^\"]+)\"|([^,\s]+))"i, line)
    match_result === nothing && throw(ArgumentError(
        "*INCLUDE requires an INPUT parameter: $(strip(line))",
    ))
    path = match_result[1] !== nothing ? match_result[1] : match_result[2]
    return String(path)
end

function expand_includes(
    content::AbstractString,
    directory::AbstractString,
    stack::Set{String},
    depth::Int,
)
    depth > INCLUDE_DEPTH_CAP && throw(ArgumentError(
        "*INCLUDE nesting exceeds $INCLUDE_DEPTH_CAP",
    ))
    pieces = String[]
    for line in split(content, '\n'; keepempty=true)
        if !include_keyword(line)
            push!(pieces, line)
            continue
        end
        relative = include_input_path(line)
        path = abspath(joinpath(directory, relative))
        path in stack && throw(ArgumentError("*INCLUDE cycle at $path"))
        isfile(path) || throw(ArgumentError("*INCLUDE file not found: $path"))
        push!(stack, path)
        expanded = expand_includes(
            read(path, String),
            dirname(path),
            stack,
            depth + 1,
        )
        pop!(stack, path)
        push!(pieces, expanded)
    end
    return join(pieces, '\n')
end

function abaqus_read_mesh(fn::String; kwargs...)
    path = abspath(fn)
    content = read(path, String)
    expanded = expand_includes(content, dirname(path), Set{String}([path]), 0)
    return abaqus_parse_mesh(expanded; kwargs...)
end
