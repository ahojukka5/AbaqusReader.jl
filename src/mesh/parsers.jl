# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

"""
Keywords that are valid ABAQUS keywords but not relevant for mesh-only parsing.

These are silently ignored by abaqus_read_mesh() to avoid noisy warnings.
The model parser (abaqus_read_model) handles these keywords.
"""
const MODEL_ONLY_KEYWORDS = Set([
    "HEADING",
    "SOLID SECTION",
    "SHELL SECTION",
    "MASS",
    "MATERIAL",
    "ELASTIC",
    "DENSITY",
    "PLASTIC",
    "EXPANSION",
    "DAMPING",
    "SPECIFIC HEAT",
    "CONDUCTIVITY",
    "INITIAL CONDITIONS",
    "AMPLITUDE",
    "SECTION CONTROLS",
    "STEP",
    "STATIC",
    "FREQUENCY",
    "END STEP",
    "BOUNDARY",
    "CLOAD",
    "DLOAD",
    "DSLOAD",
    "OUTPUT",
    "NODE OUTPUT",
    "ELEMENT OUTPUT",
    "ENERGY OUTPUT",
    "CONTACT OUTPUT",
    "NODE PRINT",
    "EL PRINT",
    "NODE FILE",
    "EL FILE",
    "CONTACT FILE"
])

"""
    parse_section(model, lines, ::Symbol, idx_start, idx_end, ::Type{Val{:NODE}})

Parse NODE section from ABAQUS input file.

Extracts node IDs and coordinates, optionally creating a node set if NSET parameter is present.
"""
function parse_section(model, lines, ::Symbol, idx_start, idx_end, ::Type{Val{:NODE}})
    nnodes = 0
    ids = Int[]
    definition = lines[idx_start]
    for line in lines[idx_start+1:idx_end]
        empty_or_comment_line(line) && continue
        m = [m.match for m in eachmatch(r"[-0-9.eE+]+", line)]
        node_id = parse(Int, m[1])
        coords = parse.(Float64, m[2:end])
        model["nodes"][node_id] = coords
        push!(ids, node_id)
        nnodes += 1
    end
    @debug "$nnodes nodes found"
    add_set!(model, definition, "node_sets", "nset", ids)
end

"""
    parse_section(model, lines, ::Symbol, idx_start, idx_end, ::Type{Val{:ELEMENT}})

Parse ELEMENT section from ABAQUS input file.

Reads element IDs and connectivity nodes. Handles multi-line element definitions where
connectivity spans multiple lines. Optionally creates element set if ELSET parameter is present.
"""
function parse_section(model, lines, ::Symbol, idx_start, idx_end, ::Type{Val{:ELEMENT}})
    ids = Int[]
    definition = lines[idx_start]
    regexp = r"TYPE=([\w\-\_]+)"i
    m = match(regexp, definition)
    m === nothing && error("Could not match regexp $regexp to line $definition")
    element_type = uppercase(m[1])
    eltype_sym = Symbol(element_type)
    eltype_nodes = element_has_nodes(eltype_sym)
    element_code = eltype_sym  # Store original ABAQUS element code
    element_type = element_has_type(eltype_sym)
    @debug "Parsing elements. Type: $(m[1]). Topology: $element_type"
    list_iterator = consumeList(lines, idx_start + 1, idx_end)
    line = list_iterator()
    while line !== nothing
        empty_or_comment_line(line) && (line = list_iterator(); continue)
        numbers = parse_numbers(line, Int)
        id = numbers[1]
        push!(ids, id)
        connectivity = numbers[2:end]
        while length(connectivity) != eltype_nodes
            @assert length(connectivity) < eltype_nodes
            line = list_iterator()
            numbers = parse_numbers(line, Int)
            push!(connectivity, numbers...)
        end
        model["elements"][id] = connectivity
        model["element_types"][id] = element_type
        model["element_codes"][id] = element_code
        line = list_iterator()
    end
    add_set!(model, definition, "element_sets", "elset", ids)
end

"""
    parse_section(model, lines, key, idx_start, idx_end, ::Union{Type{Val{:NSET}},Type{Val{:ELSET}}})

Parse NSET or ELSET section from ABAQUS input file.

Handles both explicit ID lists and GENERATE keyword for creating sets.
"""
function parse_section(model, lines, key, idx_start, idx_end, ::Union{Type{Val{:NSET}},Type{Val{:ELSET}}})
    data = Int[]
    set_regex_string = Dict(:NSET => r"((?<=NSET=)([\w\-\_]+)|(?<=NSET=\")([\w\-\_\ ]+)(?=\"))"i,
        :ELSET => r"((?<=ELSET=)([\w\-\_]+)|(?<=ELSET=\")([\w\-\_\ ]+)(?=\"))"i)
    selected_set = key == :NSET ? "node_sets" : "element_sets"
    definition = lines[idx_start]
    regex_string = set_regex_string[key]
    set_name = regex_match(regex_string, definition, 1)

    # If no set name found, error out
    set_name === nothing && error("Could not find set name in definition: $definition")

    @debug "Creating $(lowercase(string(key))) $set_name"

    if any(token -> uppercase(strip(token)) == "GENERATE", split(definition, ','))
        line = lines[idx_start+1]
        numbers = parse_numbers(line, Int)
        if length(numbers) == 2
            first_id, last_id = numbers
            step_ = 1
        elseif length(numbers) == 3
            first_id, last_id, step_ = numbers
        else
            error("GENERATE data line must contain 2 or 3 integers: $line")
        end
        set_ids = collect(first_id:step_:last_id)
        push!(data, set_ids...)
    else
        for line in lines[idx_start+1:idx_end]
            empty_or_comment_line(line) && continue
            set_ids = parse_numbers(line, Int)::Vector{Int}
            push!(data, set_ids...)
        end
    end
    model[selected_set][set_name] = data
end

"""
    parse_section(model, lines, ::Symbol, idx_start, idx_end, ::Type{Val{:SURFACE}})

Parse SURFACE section from ABAQUS input file.

Extracts surface definitions as (element_id, face_id) pairs.
"""
function parse_section(model, lines, ::Symbol, idx_start, idx_end, ::Type{Val{:SURFACE}})
    data = Vector{Tuple{Int,Symbol}}()
    definition = lines[idx_start]

    has_set_def = parse_definition(definition)
    if has_set_def === nothing
        @warn "SURFACE definition line could not be parsed: $definition"
        return
    end

    set_type = get(has_set_def, "type", "UNKNOWN")
    set_name = has_set_def["name"]

    for line in lines[idx_start+1:idx_end]
        empty_or_comment_line(line) && continue

        # Try to match element-based surface definition (element_id, face)
        m = match(r"(?P<element_id>\d+),.*(?P<element_side>S\d+).*", line)

        if m !== nothing
            # Element-based surface: element_id, face
            element_id = parse(Int, m[:element_id])
            element_side = Symbol(m[:element_side])
            push!(data, (element_id, element_side))
        else
            # Check for element-set-based surface definition (elset_name, face)
            m2 = match(r"([A-Za-z_][A-Za-z0-9_]*)\s*,\s*(S\d+)", line)
            if m2 !== nothing
                # Element-set-based surface: expand element set to individual elements
                elset_name = m2[1]
                element_side = Symbol(m2[2])

                # Look up element set in model
                if haskey(model["element_sets"], elset_name)
                    element_ids = model["element_sets"][elset_name]
                    for element_id in element_ids
                        push!(data, (element_id, element_side))
                    end
                    @debug "Expanded element set $elset_name to $(length(element_ids)) elements for surface"
                else
                    @warn "Element set '$elset_name' referenced in SURFACE not found. Skipping."
                end
            else
                error("Cannot parse SURFACE data line: $line")
            end
        end
    end

    if !isempty(data)
        model["surface_types"][set_name] = Symbol(set_type)
        model["surface_sets"][set_name] = data
    else
        @warn "SURFACE $set_name has no valid surface elements"
    end
    return
end

"""
    find_keywords(lines::Vector) -> Vector{Int}

Find lines which contain keywords (start with single asterisk, not double).

Returns vector of line indices where keywords are found.
"""
function find_keywords(lines::Vector)
    indexes = Int[]
    for (idx, line) in enumerate(lines)
        if startswith(line, "*") && !startswith(line, "**")
            push!(indexes, idx)
        end
    end
    return indexes
end

"""
    parse_abaqus(fid::IOStream, verbose::Bool=true) -> Dict

Main parser function for ABAQUS mesh input files.

Reads all lines, finds keyword sections, and dispatches to appropriate section parsers.
Returns a dictionary with mesh data structure.
"""
function parse_abaqus(fid::IO, verbose::Bool=true)
    model = Dict{String,Dict}()
    model["nodes"] = Dict{Int,Vector{Float64}}()
    model["node_sets"] = Dict{String,Vector{Int}}()
    model["elements"] = Dict{Int,Vector{Int}}()
    model["element_types"] = Dict{Int,Symbol}()
    model["element_codes"] = Dict{Int,Symbol}()
    model["element_sets"] = Dict{String,Vector{Int}}()
    model["surface_sets"] = Dict{String,Vector{Tuple{Int,Symbol}}}()
    model["surface_types"] = Dict{String,Symbol}()

    lines = readlines(fid)
    keyword_indexes = find_keywords(lines)
    push!(keyword_indexes, length(lines) + 1)
    idx_start = keyword_indexes[1]

    for idx_end in keyword_indexes[2:end]
        keyword_line = strip(uppercase(lines[idx_start]))
        keyword = strip(regex_match(r"\s*([\w ]+)", keyword_line, 1))
        k_sym = Symbol(keyword)

        # Dispatch based on keyword symbol
        try
            if k_sym == :NODE
                parse_section(model, lines, k_sym, idx_start, idx_end - 1, Val{:NODE})
            elseif k_sym == :ELEMENT
                parse_section(model, lines, k_sym, idx_start, idx_end - 1, Val{:ELEMENT})
            elseif k_sym == :NSET
                parse_section(model, lines, k_sym, idx_start, idx_end - 1, Val{:NSET})
            elseif k_sym == :ELSET
                parse_section(model, lines, k_sym, idx_start, idx_end - 1, Val{:ELSET})
            elseif k_sym == :SURFACE
                parse_section(model, lines, k_sym, idx_start, idx_end - 1, Val{:SURFACE})
            elseif k_sym == :INCLUDE
                throw(ArgumentError(
                    "*INCLUDE requires a file path; use abaqus_read_mesh",
                ))
            elseif keyword in MODEL_ONLY_KEYWORDS
                # Silently skip known model-only keywords
                @debug "Skipping model-only keyword: $keyword"
            else
                verbose && @warn "Unknown section: '$(keyword)'"
            end
        catch e
            @error "Error parsing section $keyword" exception = e
            rethrow()
        end

        idx_start = idx_end
    end
    return model
end

"""
    consumeList(arr, start, stop) -> Function

Create an iterator for consuming lines from an array.

Used for handling multi-line element definitions where connectivity
nodes might span multiple lines.
"""
function consumeList(arr, start, stop)
    idx = start - 1
    function _it()
        idx += 1
        if idx > stop
            return nothing
        end
        arr[idx]
    end
    _it
end
