# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/AbaqusReader.jl/blob/master/LICENSE

"""
    empty_or_comment_line(line::AbstractString) -> Bool

Check if a line is a comment or empty.

Returns true if line starts with comment character "**" or is empty.
"""
empty_or_comment_line(line::AbstractString) = startswith(line, "**") || isempty(line)

"""
    matchset(definition::AbstractString) -> Vector{String}

Match words from both sides of '=' character in a definition line.
"""
function matchset(definition::AbstractString)
    regexp = r"([\w\_\-]+[ ]*=[ ]*[\w\_\-]+)"
    return [m.match for m in eachmatch(regexp, definition)]
end

"""
    parse_definition(definition::AbstractString) -> Union{Dict{String,String}, Nothing}

Parse string to get set type and name from ABAQUS keyword parameters.

Returns a dictionary of lowercase parameter names to values, or nothing if no parameters found.
"""
function parse_definition(definition::AbstractString)
    set_defs = Dict{String,String}()
    set_definition = matchset(definition)
    isempty(set_definition) && return nothing
    for x in set_definition
        name, vals = map(strip, split(x, "="))
        set_defs[lowercase(name)] = vals
    end
    return set_defs
end

"""
    parse_numbers(line, type_::Type{T}) -> Vector{T} where T

Parse all the numbers from a string and convert to specified type.
"""
function parse_numbers(line, type_::Type{T})::Vector{T} where {T}
    regexp = r"-?[0-9]+"
    matches = (m.match for m in eachmatch(regexp, line))
    return map(x -> parse(type_, x), matches)
end

"""
    add_set!(model, definition, model_key, abaqus_key, ids)

Add a set to the model if the set definition exists in the keyword line.

# Arguments
- `model`: The model dictionary to update
- `definition`: The keyword definition line (e.g., "*NODE, NSET=ALLNODES")
- `model_key`: Key in model dict where set should be stored (e.g., "node_sets")
- `abaqus_key`: ABAQUS parameter name to look for (e.g., "nset")
- `ids`: Vector of IDs to store in the set
"""
function add_set!(model, definition, model_key, abaqus_key, ids)
    has_set_def = parse_definition(definition)
    has_set_def === nothing && return
    if haskey(has_set_def, abaqus_key)
        set_name = has_set_def[abaqus_key]
        @debug "Adding $abaqus_key: $set_name"
        model[model_key][set_name] = ids
    end
end

"""
    regex_match(regex_str::Regex, line::AbstractString, idx::Int) -> String

Custom regex to find match from string. Index used if there are multiple matches.
"""
function regex_match(regex_str::Regex, line::AbstractString, idx::Int)
    matches = collect((m.match for m in eachmatch(regex_str, line)))
    return isempty(matches) ? nothing : matches[idx]
end
