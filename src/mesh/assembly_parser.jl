# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

"""
    parse_assembly_mesh(io::IO; verbose=true)

Parse ABAQUS input files with modern PART/ASSEMBLY structure.

This parser handles structured ABAQUS files that use:
- *PART sections to define individual parts with their own nodes/elements
- *ASSEMBLY section to combine parts together

Returns a dictionary with:
- "parts": Dict{String, Dict} - Each part's mesh data (nodes, elements, etc.)
- "assembly": Dict - Assembly-level data (sets, instances, etc.)
- "nodes": Dict - Flattened nodes from all parts
- "elements": Dict - Flattened elements from all parts
- "element_types": Dict - Element types for all elements

The flattened mesh allows backward compatibility with code expecting the flat format.
"""
function parse_assembly_mesh(io::IO; verbose=true)
    lines = readlines(io)

    # Initialize result structure
    result = Dict{String,Any}(
        "parts" => Dict{String,Dict{String,Any}}(),
        "assembly" => Dict{String,Any}(),
        "nodes" => Dict{Int,Vector{Float64}}(),
        "elements" => Dict{Int,Vector{Int}}(),
        "element_types" => Dict{Int,Symbol}(),
        "element_codes" => Dict{Int,Symbol}(),
        "element_sets" => Dict{String,Vector{Int}}(),
        "node_sets" => Dict{String,Vector{Int}}(),
        "surface_sets" => Dict{String,Vector{Tuple{Int,Symbol}}}(),
        "surface_types" => Dict{String,Symbol}()
    )

    current_part = nothing
    in_assembly = false
    i = 1

    while i <= length(lines)
        line = strip(lines[i])

        # Skip empty lines and comments
        if isempty(line) || startswith(line, "**")
            i += 1
            continue
        end

        line_upper = uppercase(line)

        # Detect *PART
        if startswith(line_upper, "*PART")
            m = match(r"NAME\s*=\s*([^,\s]+)"i, line)
            if m !== nothing
                part_name = m[1]
                @debug "Starting PART: $part_name"
                current_part = part_name
                result["parts"][part_name] = Dict{String,Any}(
                    "nodes" => Dict{Int,Vector{Float64}}(),
                    "elements" => Dict{Int,Vector{Int}}(),
                    "element_types" => Dict{Int,Symbol}(),
                    "element_codes" => Dict{Int,Symbol}(),
                    "element_sets" => Dict{String,Vector{Int}}(),
                    "node_sets" => Dict{String,Vector{Int}}(),
                    "surface_sets" => Dict{String,Vector{Tuple{Int,Symbol}}}(),
                    "surface_types" => Dict{String,Symbol}()
                )
            end
            i += 1
            continue
        end

        # Detect *END PART
        if startswith(line_upper, "*END PART")
            @debug "Ending PART: $current_part"
            current_part = nothing
            i += 1
            continue
        end

        # Detect *ASSEMBLY
        if startswith(line_upper, "*ASSEMBLY")
            @debug "Starting ASSEMBLY"
            in_assembly = true
            current_part = nothing
            i += 1
            continue
        end

        # Detect *END ASSEMBLY
        if startswith(line_upper, "*END ASSEMBLY")
            @debug "Ending ASSEMBLY"
            in_assembly = false
            i += 1
            continue
        end

        # Find the next keyword
        next_keyword_idx = i + 1
        while next_keyword_idx <= length(lines)
            next_line = strip(lines[next_keyword_idx])
            if !isempty(next_line) && startswith(next_line, "*") && !startswith(next_line, "**")
                break
            end
            next_keyword_idx += 1
        end

        # Determine target dictionary (part-specific or assembly/global)
        target_dict = if current_part !== nothing
            result["parts"][current_part]
        elseif in_assembly
            result["assembly"]
        else
            result
        end

        # Parse sections using the existing parser
        keyword = :UNKNOWN
        if startswith(line_upper, "*NODE")
            keyword = :NODE
        elseif occursin(r"\*ELEMENT"i, line)
            keyword = :ELEMENT
        elseif occursin(r"\*NSET"i, line)
            keyword = :NSET
        elseif occursin(r"\*ELSET"i, line)
            keyword = :ELSET
        elseif occursin(r"\*SURFACE"i, line)
            keyword = :SURFACE
        end

        if keyword != :UNKNOWN
            try
                parse_section(target_dict, lines, keyword, i, next_keyword_idx - 1, Val{keyword})
            catch e
                if verbose
                    @warn "Error parsing section $keyword in part/assembly" exception = e
                end
            end
        end

        i = next_keyword_idx
    end

    # Flatten all parts into global nodes/elements for backward compatibility
    node_offset = 0
    element_offset = 0

    for part_name in sort(collect(keys(result["parts"])))
        part_data = result["parts"][part_name]
        @debug "Flattening PART: $part_name ($(length(part_data["nodes"])) nodes, $(length(part_data["elements"])) elements)"

        # Merge nodes
        for (node_id, coords) in part_data["nodes"]
            result["nodes"][node_id+node_offset] = coords
        end

        # Merge elements (adjusting node references)
        for (elem_id, connectivity) in part_data["elements"]
            adjusted_connectivity = [node_id + node_offset for node_id in connectivity]
            result["elements"][elem_id+element_offset] = adjusted_connectivity
            result["element_types"][elem_id+element_offset] = part_data["element_types"][elem_id]
            result["element_codes"][elem_id+element_offset] = part_data["element_codes"][elem_id]
        end

        # Merge element sets
        for (set_name, elem_ids) in part_data["element_sets"]
            prefixed_name = "$(part_name).$(set_name)"
            adjusted_ids = [id + element_offset for id in elem_ids]
            result["element_sets"][prefixed_name] = adjusted_ids
        end

        # Merge node sets
        for (set_name, node_ids) in part_data["node_sets"]
            prefixed_name = "$(part_name).$(set_name)"
            adjusted_ids = [id + node_offset for id in node_ids]
            result["node_sets"][prefixed_name] = adjusted_ids
        end

        # Merge surface sets
        for (surface_name, surface_pairs) in part_data["surface_sets"]
            prefixed_name = "$(part_name).$(surface_name)"
            adjusted_pairs = [(elid + element_offset, side) for (elid, side) in surface_pairs]
            result["surface_sets"][prefixed_name] = adjusted_pairs

            if haskey(part_data["surface_types"], surface_name)
                result["surface_types"][prefixed_name] = part_data["surface_types"][surface_name]
            end
        end

        # Update offsets for next part
        if !isempty(part_data["nodes"])
            node_offset = maximum(keys(result["nodes"]))
        end
        if !isempty(part_data["elements"])
            element_offset = maximum(keys(result["elements"]))
        end
    end

    @debug "Flattened mesh: $(length(result["nodes"])) nodes, $(length(result["elements"])) elements"

    return result
end

"""
    detect_assembly_format(lines) -> Bool

Detect if the input file uses the modern PART/ASSEMBLY structure.
Returns true if *PART keyword is found.
"""
function detect_assembly_format(lines)
    for line in lines
        line_upper = uppercase(strip(String(line)))
        if startswith(line_upper, "*PART")
            return true
        end
    end
    return false
end
