"""
    Keyword

Parsed keyword line with options.

# Fields
- `name::String` - Keyword name (e.g., "MATERIAL", "STEP")
- `options::Vector{Union{String,Pair}}` - Keyword options/parameters
"""
mutable struct Keyword
    name::String
    options::Vector{Union{String,Pair}}
end

"""
    AbaqusReaderState

Parser state tracking current section and accumulated data.

# Fields
- `section::Union{Keyword,Nothing}` - Current keyword section
- `material::Union{AbstractMaterial,Nothing}` - Current material being defined
- `property::Union{AbstractProperty,Nothing}` - Current property being defined
- `step::Union{AbstractStep,Nothing}` - Current analysis step
- `data::Vector{String}` - Accumulated data lines for current section
"""
mutable struct AbaqusReaderState
    section::Union{Keyword,Nothing}
    material::Union{AbstractMaterial,Nothing}
    property::Union{AbstractProperty,Nothing}
    step::Union{AbstractStep,Nothing}
    data::Vector{String}
end

"""
    get_data(state::AbaqusReaderState) -> Vector

Parse accumulated data lines into structured data.

Splits CSV data and parses numbers.
"""
function get_data(state::AbaqusReaderState)
    data = []
    for row in state.data
        row = strip(row, [' ', ','])
        col = split(row, ',')
        col = map(Meta.parse, col)
        push!(data, col)
    end
    return data
end

"""
    get_options(state::AbaqusReaderState) -> Dict

Get options dictionary from current section keyword.

Handles both key-value pairs and boolean flags (bare strings).
Boolean flags are stored with value `true`.
"""
function get_options(state::AbaqusReaderState)
    section = state.section
    section === nothing && return Dict{String,Any}()

    options = Dict{String,Any}()
    for item in section.options
        if item isa Pair
            # Key-value pair: OPTION=VALUE
            options[String(first(item))] = String(last(item))
        elseif item isa String
            # Boolean flag: just OPTION (e.g., NLGEOM, PERTURBATION)
            options[item] = true
        end
    end
    return options
end

"""
    get_option(state::AbaqusReaderState, what::String)

Get specific option value from current section.
"""
function get_option(state::AbaqusReaderState, what::String)
    return get_options(state)[what]
end

Base.length(state::AbaqusReaderState) = length(state.data)

"""
    is_comment(line::AbstractString) -> Bool

Check if line is a comment (starts with "**").
"""
is_comment(line::AbstractString) = startswith(line, "**")

"""
    is_keyword(line::AbstractString) -> Bool

Check if line is a keyword (starts with "*" but not "**").
"""
is_keyword(line::AbstractString) = startswith(line, "*") && !is_comment(line)
