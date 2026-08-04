# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

function instance_data_lines(lines, first_line::Int, last_line::Int)
    data = String[]
    for index in first_line:last_line
        line = strip(lines[index])
        isempty(line) && continue
        startswith(line, "**") && continue
        startswith(line, "*") && throw(ArgumentError(
            "unexpected keyword inside *INSTANCE placement data: $line",
        ))
        push!(data, line)
    end
    return data
end

function instance_numbers(
    line::AbstractString,
    expected::Int,
    description::AbstractString,
)
    fields = [
        strip(field) for field in split(String(line), ',')
        if !isempty(strip(field))
    ]
    length(fields) == expected || throw(ArgumentError(
        "$description requires $expected numeric values, got $(length(fields))",
    ))
    try
        return parse.(Float64, fields)
    catch exception
        throw(ArgumentError(
            "$description contains a non-numeric value: $(sprint(showerror, exception))",
        ))
    end
end

function parse_instance_placement(data::Vector{String})
    length(data) <= 2 || throw(ArgumentError(
        "*INSTANCE placement accepts at most one translation and one rotation line",
    ))

    translation = [0.0, 0.0, 0.0]
    rotation = nothing
    if length(data) == 1
        values = [
            strip(field) for field in split(data[1], ',')
            if !isempty(strip(field))
        ]
        if length(values) == 3
            translation = instance_numbers(data[1], 3, "instance translation")
        elseif length(values) == 7
            rotation_values = instance_numbers(data[1], 7, "instance rotation")
            rotation = Dict{String,Any}(
                "axis_start" => rotation_values[1:3],
                "axis_end" => rotation_values[4:6],
                "angle_degrees" => rotation_values[7],
            )
        else
            throw(ArgumentError(
                "single-line *INSTANCE placement must contain 3 translation " *
                "or 7 rotation values",
            ))
        end
    elseif length(data) == 2
        translation = instance_numbers(data[1], 3, "instance translation")
        rotation_values = instance_numbers(data[2], 7, "instance rotation")
        rotation = Dict{String,Any}(
            "axis_start" => rotation_values[1:3],
            "axis_end" => rotation_values[4:6],
            "angle_degrees" => rotation_values[7],
        )
    end

    return translation, rotation
end

function find_end_instance(lines, start_index::Int)
    for index in (start_index + 1):length(lines)
        startswith(uppercase(strip(lines[index])), "*END INSTANCE") &&
            return index
    end
    throw(ArgumentError("*INSTANCE section is missing *END INSTANCE"))
end

function parse_instance_record(lines, start_index::Int, end_index::Int)
    header = strip(lines[start_index])
    name_match = match(r"NAME\s*=\s*([^,\s]+)"i, header)
    part_match = match(r"PART\s*=\s*([^,\s]+)"i, header)
    name_match === nothing && throw(ArgumentError(
        "*INSTANCE requires a NAME parameter",
    ))
    part_match === nothing && throw(ArgumentError(
        "*INSTANCE requires a PART parameter",
    ))

    translation, rotation = parse_instance_placement(instance_data_lines(
        lines,
        start_index + 1,
        end_index - 1,
    ))
    return Dict{String,Any}(
        "name" => String(name_match[1]),
        "part" => String(part_match[1]),
        "translation" => translation,
        "rotation" => rotation,
    )
end

function coordinates3(coordinates)
    isempty(coordinates) && throw(ArgumentError(
        "instance node has no coordinates",
    ))
    return (
        Float64(coordinates[1]),
        length(coordinates) >= 2 ? Float64(coordinates[2]) : 0.0,
        length(coordinates) >= 3 ? Float64(coordinates[3]) : 0.0,
    )
end

function rotate_instance_point(point, rotation::AbstractDict)
    axis_start_values = rotation["axis_start"]
    axis_end_values = rotation["axis_end"]
    axis_start = coordinates3(axis_start_values)
    axis_end = coordinates3(axis_end_values)
    axis = (
        axis_end[1] - axis_start[1],
        axis_end[2] - axis_start[2],
        axis_end[3] - axis_start[3],
    )
    axis_length = sqrt(axis[1]^2 + axis[2]^2 + axis[3]^2)
    axis_length > eps(Float64) || throw(ArgumentError(
        "instance rotation axis must have nonzero length",
    ))
    unit_axis = (
        axis[1] / axis_length,
        axis[2] / axis_length,
        axis[3] / axis_length,
    )
    relative = (
        point[1] - axis_start[1],
        point[2] - axis_start[2],
        point[3] - axis_start[3],
    )
    cosine = cosd(Float64(rotation["angle_degrees"]))
    sine = sind(Float64(rotation["angle_degrees"]))
    cross = (
        unit_axis[2] * relative[3] - unit_axis[3] * relative[2],
        unit_axis[3] * relative[1] - unit_axis[1] * relative[3],
        unit_axis[1] * relative[2] - unit_axis[2] * relative[1],
    )
    projection = unit_axis[1] * relative[1] +
        unit_axis[2] * relative[2] +
        unit_axis[3] * relative[3]
    scale = 1.0 - cosine
    return (
        axis_start[1] + relative[1] * cosine + cross[1] * sine +
            unit_axis[1] * projection * scale,
        axis_start[2] + relative[2] * cosine + cross[2] * sine +
            unit_axis[2] * projection * scale,
        axis_start[3] + relative[3] * cosine + cross[3] * sine +
            unit_axis[3] * projection * scale,
    )
end

function transform_instance_coordinates(coordinates, instance::AbstractDict)
    point = coordinates3(coordinates)
    translation = instance["translation"]
    translated = (
        point[1] + Float64(translation[1]),
        point[2] + Float64(translation[2]),
        point[3] + Float64(translation[3]),
    )
    rotation = instance["rotation"]
    transformed = rotation === nothing ? translated :
        rotate_instance_point(translated, rotation)
    return collect(transformed)
end

function flatten_part!(
    result::Dict{String,Any},
    part_name::AbstractString,
    prefix::AbstractString,
    part_data::AbstractDict,
    instance,
    node_offset::Int,
    element_offset::Int,
)
    @debug "Flattening PART $part_name as $prefix ($(length(part_data["nodes"])) nodes, $(length(part_data["elements"])) elements)"

    for (node_id, coordinates) in sort(collect(part_data["nodes"]); by=first)
        global_node_id = node_id + node_offset
        result["nodes"][global_node_id] = instance === nothing ?
            copy(coordinates) : transform_instance_coordinates(coordinates, instance)
    end

    for (element_id, connectivity) in sort(
        collect(part_data["elements"]);
        by=first,
    )
        global_element_id = element_id + element_offset
        result["elements"][global_element_id] = [
            node_id + node_offset for node_id in connectivity
        ]
        result["element_types"][global_element_id] =
            part_data["element_types"][element_id]
        result["element_codes"][global_element_id] =
            part_data["element_codes"][element_id]
    end

    for (set_name, element_ids) in sort(
        collect(part_data["element_sets"]);
        by=first,
    )
        result["element_sets"]["$(prefix).$(set_name)"] = [
            element_id + element_offset for element_id in element_ids
        ]
    end
    for (set_name, node_ids) in sort(
        collect(part_data["node_sets"]);
        by=first,
    )
        result["node_sets"]["$(prefix).$(set_name)"] = [
            node_id + node_offset for node_id in node_ids
        ]
    end
    for (surface_name, surface_pairs) in sort(
        collect(part_data["surface_sets"]);
        by=first,
    )
        prefixed_name = "$(prefix).$(surface_name)"
        result["surface_sets"][prefixed_name] = [
            (element_id + element_offset, side)
            for (element_id, side) in surface_pairs
        ]
        if haskey(part_data["surface_types"], surface_name)
            result["surface_types"][prefixed_name] =
                part_data["surface_types"][surface_name]
        end
    end

    next_node_offset = isempty(part_data["nodes"]) ? node_offset :
        maximum(keys(result["nodes"]))
    next_element_offset = isempty(part_data["elements"]) ? element_offset :
        maximum(keys(result["elements"]))
    return next_node_offset, next_element_offset
end

"""
    parse_assembly_mesh(io::IO; verbose=true)

Parse ABAQUS input files with modern PART/ASSEMBLY structure.

This parser handles structured ABAQUS files that use:
- `*PART` sections to define reusable local meshes;
- `*INSTANCE` sections to place parts with optional translation and rotation;
- `*ASSEMBLY` sections to combine instances.

Returns a dictionary with part data, assembly instance metadata, and a flattened
mesh. When instances are declared, flattened set and surface names are prefixed
with the instance name. PART-only input retains the legacy part-name prefix.
"""
function parse_assembly_mesh(io::IO; verbose=true)
    lines = readlines(io)

    result = Dict{String,Any}(
        "parts" => Dict{String,Dict{String,Any}}(),
        "assembly" => Dict{String,Any}(
            "instances" => Dict{String,Dict{String,Any}}(),
        ),
        "instance_parts" => Dict{String,String}(),
        "nodes" => Dict{Int,Vector{Float64}}(),
        "elements" => Dict{Int,Vector{Int}}(),
        "element_types" => Dict{Int,Symbol}(),
        "element_codes" => Dict{Int,Symbol}(),
        "element_sets" => Dict{String,Vector{Int}}(),
        "node_sets" => Dict{String,Vector{Int}}(),
        "surface_sets" => Dict{String,Vector{Tuple{Int,Symbol}}}(),
        "surface_types" => Dict{String,Symbol}(),
    )

    current_part = nothing
    in_assembly = false
    index = 1

    while index <= length(lines)
        line = strip(lines[index])
        if isempty(line) || startswith(line, "**")
            index += 1
            continue
        end

        line_upper = uppercase(line)
        if startswith(line_upper, "*PART")
            name_match = match(r"NAME\s*=\s*([^,\s]+)"i, line)
            if name_match !== nothing
                part_name = String(name_match[1])
                haskey(result["parts"], part_name) && throw(ArgumentError(
                    "duplicate PART name: $part_name",
                ))
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
                    "surface_types" => Dict{String,Symbol}(),
                )
            end
            index += 1
            continue
        end

        if startswith(line_upper, "*END PART")
            @debug "Ending PART: $current_part"
            current_part = nothing
            index += 1
            continue
        end

        if startswith(line_upper, "*ASSEMBLY")
            @debug "Starting ASSEMBLY"
            in_assembly = true
            current_part = nothing
            index += 1
            continue
        end

        if startswith(line_upper, "*END ASSEMBLY")
            @debug "Ending ASSEMBLY"
            in_assembly = false
            index += 1
            continue
        end

        if startswith(line_upper, "*INSTANCE")
            in_assembly || throw(ArgumentError(
                "*INSTANCE must appear inside *ASSEMBLY",
            ))
            end_index = find_end_instance(lines, index)
            instance = parse_instance_record(lines, index, end_index)
            instance_name = String(instance["name"])
            instances = result["assembly"]["instances"]
            haskey(instances, instance_name) && throw(ArgumentError(
                "duplicate INSTANCE name: $instance_name",
            ))
            instances[instance_name] = instance
            index = end_index + 1
            continue
        end

        if startswith(line_upper, "*END INSTANCE")
            index += 1
            continue
        end

        next_keyword_index = index + 1
        while next_keyword_index <= length(lines)
            next_line = strip(lines[next_keyword_index])
            if !isempty(next_line) && startswith(next_line, "*") &&
               !startswith(next_line, "**")
                break
            end
            next_keyword_index += 1
        end

        target = if current_part !== nothing
            result["parts"][current_part]
        elseif in_assembly
            result["assembly"]
        else
            result
        end

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
                parse_section(
                    target,
                    lines,
                    keyword,
                    index,
                    next_keyword_index - 1,
                    Val{keyword},
                )
            catch exception
                if verbose
                    @warn "Error parsing section $keyword in part/assembly" exception
                end
            end
        end

        index = next_keyword_index
    end

    node_offset = 0
    element_offset = 0
    instances = result["assembly"]["instances"]
    if isempty(instances)
        for part_name in sort(collect(keys(result["parts"])))
            node_offset, element_offset = flatten_part!(
                result,
                part_name,
                part_name,
                result["parts"][part_name],
                nothing,
                node_offset,
                element_offset,
            )
        end
    else
        for instance_name in sort(collect(keys(instances)))
            instance = instances[instance_name]
            part_name = String(instance["part"])
            haskey(result["parts"], part_name) || throw(ArgumentError(
                "INSTANCE $instance_name references unknown PART $part_name",
            ))
            result["instance_parts"][instance_name] = part_name
            node_offset, element_offset = flatten_part!(
                result,
                part_name,
                instance_name,
                result["parts"][part_name],
                instance,
                node_offset,
                element_offset,
            )
        end
    end

    @debug "Flattened mesh: $(length(result["nodes"])) nodes, $(length(result["elements"])) elements"
    return result
end

"""
    detect_assembly_format(lines) -> Bool

Detect if the input file uses the modern PART/ASSEMBLY structure.
Returns true if `*PART` is found.
"""
function detect_assembly_format(lines)
    for line in lines
        line_upper = uppercase(strip(String(line)))
        startswith(line_upper, "*PART") && return true
    end
    return false
end
