"""
    maybe_close_section!(model, state)

Close current section and process accumulated data.

Dispatches to specific close handlers based on section name.
"""
function maybe_close_section!(model, state)
    state.section === nothing && return
    section_name = state.section.name
    @debug "Close section: $section_name"

    # Direct dispatch based on section name
    if section_name == "HEADING"
        close_heading!(model, state)
    elseif section_name == "SOLID SECTION"
        close_solid_section!(model, state)
    elseif section_name == "SHELL SECTION"
        close_shell_section!(model, state)
    elseif section_name == "MASS"
        close_mass_section!(model, state)
    elseif section_name == "ELASTIC"
        close_elastic!(model, state)
    elseif section_name == "DENSITY"
        close_density!(model, state)
    elseif section_name == "PLASTIC"
        close_plastic!(model, state)
    elseif section_name == "EXPANSION"
        close_expansion!(model, state)
    elseif section_name == "DAMPING"
        close_damping!(model, state)
    elseif section_name == "STATIC"
        close_static!(model, state)
    elseif section_name == "FREQUENCY"
        close_frequency!(model, state)
    elseif section_name in ("BOUNDARY", "CLOAD", "DLOAD", "DSLOAD")
        close_boundary_condition!(model, state)
    elseif section_name in ("NODE PRINT", "EL PRINT", "SECTION PRINT", "NODE FILE", "EL FILE", "CONTACT FILE")
        close_output_request!(model, state)
    elseif section_name in ("NODE OUTPUT", "ELEMENT OUTPUT", "ENERGY OUTPUT", "CONTACT OUTPUT")
        close_output_definition!(model, state)
    else
        @debug "No close handler for $section_name"
    end

    state.section = nothing
end

"""
    maybe_open_section!(model, state)

Open new section and initialize state.

Dispatches to specific open handlers based on section name.
"""
function maybe_open_section!(model, state)
    section_name = state.section.name
    section_options = state.section.options
    @debug "New section: $section_name with options $section_options"

    # Direct dispatch based on section name
    if section_name == "HEADING"
        open_heading!(model, state)
    elseif section_name == "SOLID SECTION"
        open_solid_section!(model, state)
    elseif section_name == "SHELL SECTION"
        open_shell_section!(model, state)
    elseif section_name == "MASS"
        open_mass_section!(model, state)
    elseif section_name == "MATERIAL"
        open_material!(model, state)
    elseif section_name == "STEP"
        open_step!(model, state)
    elseif section_name == "STATIC"
        open_static!(model, state)
    elseif section_name == "FREQUENCY"
        open_frequency!(model, state)
    elseif section_name == "OUTPUT"
        open_output!(model, state)
    elseif section_name == "END STEP"
        open_end_step!(model, state)
    else
        @debug "No open handler for $section_name"
    end
end

"""
    new_section!(model, state, line::String)

Start a new keyword section.

Closes previous section, parses new keyword, and opens new section.
"""
function new_section!(model, state, line::String)
    maybe_close_section!(model, state)
    state.data = []
    state.section = parse_keyword(line)
    maybe_open_section!(model, state)
end

"""
    process_line!(model, state, line::String)

Process a data line within current section.

Accumulates data lines or closes section if new keyword detected.
"""
function process_line!(model, state, line::String)
    if state.section === nothing
        @debug "section = nothing! line = $line"
        return
    end
    if is_keyword(line)
        @warn("missing keyword? line = $line")
        # close section, this is probably keyword and collecting data should stop.
        maybe_close_section!(model, state)
        return
    end
    push!(state.data, line)
end

# =============================================================================
# Section Handlers - Model Description
# =============================================================================

"""
    open_heading!(model, state)

Open HEADING section and store heading text.
"""
function open_heading!(model, state)
    # Heading text is on subsequent lines
    @debug "HEADING section opened"
end

"""
    close_heading!(model, state)

Close HEADING section and store text in model.
"""
function close_heading!(model, state)
    if length(state.data) > 0
        model.heading = join(state.data, "\n")
    end
end

# =============================================================================
# Section Handlers - Properties
# =============================================================================

"""
    open_solid_section!(model, state)

Open SOLID SECTION and create property linking element set to material.
"""
function open_solid_section!(model, state)
    element_set = Symbol(get_option(state, "ELSET"))
    material_name = Symbol(get_option(state, "MATERIAL"))
    controls = haskey(get_options(state), "CONTROLS") ? Symbol(get_option(state, "CONTROLS")) : nothing
    property = SolidSection(element_set, material_name, controls, nothing)
    state.property = property
    push!(model.properties, property)
end

"""
    close_solid_section!(model, state)

Close SOLID SECTION and parse optional area parameter for truss elements.

For truss elements (T2D2, T3D2), the line after *SOLID SECTION contains the
cross-sectional area. This function reads that data if present.
"""
function close_solid_section!(model, state)
    if state.property !== nothing && state.property isa SolidSection
        # Check if there's data to parse (area for truss elements)
        if !isempty(state.data)
            # Parse area from first data line
            data_line = strip(state.data[1])
            if !isempty(data_line)
                # Remove trailing comma if present
                data_line = replace(data_line, r",$" => "")
                area = parse(Float64, data_line)
                state.property.area = area
                @debug "Parsed SOLID SECTION area: $area"
            end
        end
    end
    state.property = nothing
end

"""
    open_shell_section!(model, state)

Open SHELL SECTION and create shell property.
"""
function open_shell_section!(model, state)
    element_set = Symbol(get_option(state, "ELSET"))
    material_name = Symbol(get_option(state, "MATERIAL"))
    # Don't set state.property here - will be set in close_shell_section!
end

"""
    close_shell_section!(model, state)

Close SHELL SECTION and process thickness data.
"""
function close_shell_section!(model, state)
    if length(state) > 0
        data = first(get_data(state))
        thickness = data[1]
        num_points = length(data) > 1 ? Int(data[2]) : 5
    else
        thickness = 1.0
        num_points = 5
    end

    options = get_options(state)
    element_set = Symbol(options["ELSET"])
    material_name = Symbol(options["MATERIAL"])

    property = ShellSection(element_set, material_name, thickness, num_points)
    push!(model.properties, property)
    state.property = nothing
end

"""
    open_mass_section!(model, state)

Open MASS section.
"""
function open_mass_section!(model, state)
    state.property = :MASS_PENDING
end

"""
    close_mass_section!(model, state)

Close MASS section and process mass data.
"""
function close_mass_section!(model, state)
    if length(state) > 0
        data = first(get_data(state))
        mass_value = data[1]
    else
        mass_value = 1.0
    end

    options = get_options(state)
    element_set = Symbol(options["ELSET"])

    property = MassSection(element_set, mass_value)
    push!(model.properties, property)
    state.property = nothing
end

# =============================================================================
# Section Handlers - Materials
# =============================================================================

"""
    open_material!(model, state)

Open MATERIAL section and create new material.
"""
function open_material!(model, state)
    material_name = Symbol(get_option(state, "NAME"))
    material = Material(material_name, [])
    state.material = material
    model.materials[material_name] = material
end

"""
    close_elastic!(model, state)

Close ELASTIC section and add elastic properties to current material.
"""
function close_elastic!(model, state)
    @assert length(state) == 1
    E, nu = first(get_data(state))
    material_property = Elastic(E, nu)
    material = state.material
    @assert material !== nothing
    push!(material.properties, material_property)
end

"""
    close_density!(model, state)

Close DENSITY section and add density to current material.
"""
function close_density!(model, state)
    @assert length(state) == 1
    density = first(first(get_data(state)))
    material_property = Density(density)
    material = state.material
    @assert material !== nothing
    push!(material.properties, material_property)
end

"""
    close_plastic!(model, state)

Close PLASTIC section and add plasticity data to current material.
"""
function close_plastic!(model, state)
    table = Tuple{Float64,Float64}[]
    for row in get_data(state)
        stress = row[1]
        strain = row[2]
        push!(table, (stress, strain))
    end
    material_property = Plastic(table)
    material = state.material
    @assert material !== nothing
    push!(material.properties, material_property)
end

"""
    close_expansion!(model, state)

Close EXPANSION section and add thermal expansion to current material.
"""
function close_expansion!(model, state)
    @assert length(state) == 1
    alpha = first(first(get_data(state)))
    material_property = Expansion(alpha)
    material = state.material
    @assert material !== nothing
    push!(material.properties, material_property)
end

"""
    close_damping!(model, state)

Close DAMPING section and add damping to current material.
"""
function close_damping!(model, state)
    options = get_options(state)
    alpha = haskey(options, "ALPHA") ? parse(Float64, options["ALPHA"]) : 0.0
    beta = haskey(options, "BETA") ? parse(Float64, options["BETA"]) : 0.0
    material_property = Damping(alpha, beta)
    material = state.material
    @assert material !== nothing
    push!(material.properties, material_property)
end

# =============================================================================
# Section Handlers - Steps
# =============================================================================

"""
    open_step!(model, state)

Open STEP section and create new analysis step.
"""
function open_step!(model, state)
    options = get_options(state)
    step_name = haskey(options, "NAME") ? options["NAME"] : nothing
    step_options = Dict(options)
    step_ = Step(step_name, nothing, step_options, nothing, Vector(), Vector())
    state.step = step_
    push!(model.steps, step_)
end

"""
    open_static!(model, state)

Mark current step as STATIC analysis and parse parameters.

STATIC parameters (data line):
- initial_time_increment
- total_time_period
- minimum_time_increment (optional)
- maximum_time_increment (optional)
"""
function open_static!(model, state)
    state.step === nothing && error("*STATIC outside *STEP ?")
    state.step.kind = :STATIC
end

"""
    close_static!(model, state)

Close STATIC section and capture time increment parameters.
"""
function close_static!(model, state)
    if length(state.data) > 0
        # Parse STATIC parameters: initial_inc, total_time, [min_inc], [max_inc]
        data_line = first(state.data)
        # Split by comma and parse each float
        params = [parse(Float64, strip(x)) for x in split(data_line, ',')]
        state.step.parameters = params
        @debug "STATIC parameters: $params"
    end
end

"""
    open_frequency!(model, state)

Mark current step as FREQUENCY analysis and parse parameters.

FREQUENCY parameters (data line):
- number_of_eigenvalues
- [min_eigenvalue]
- [max_eigenvalue]
"""
function open_frequency!(model, state)
    state.step === nothing && error("*FREQUENCY outside *STEP ?")
    state.step.kind = :FREQUENCY
end

"""
    close_frequency!(model, state)

Close FREQUENCY section and capture eigenvalue extraction parameters.
"""
function close_frequency!(model, state)
    if length(state.data) > 0
        # Parse FREQUENCY parameters: num_eigenvalues, [min], [max], [shift]
        data_line = first(state.data)
        # Split by comma and parse, handling empty fields
        params = Float64[]
        for x in split(data_line, ',')
            stripped = strip(x)
            if !isempty(stripped)
                push!(params, parse(Float64, stripped))
            else
                push!(params, NaN)  # Use NaN for missing optional parameters
            end
        end
        state.step.parameters = params
        @debug "FREQUENCY parameters: $params"
    end
end

"""
    open_output!(model, state)

Open OUTPUT section (just marks section type, actual output definitions follow).
"""
function open_output!(model, state)
    # OUTPUT is a container, actual definitions come in sub-keywords
    @debug "OUTPUT section opened"
end

"""
    open_end_step!(model, state)

Close current step (END STEP keyword).
"""
function open_end_step!(model, state)
    state.step = nothing
end

# =============================================================================
# Section Handlers - Boundary Conditions
# =============================================================================

"""
    close_boundary_condition!(model, state)

Close boundary condition section (BOUNDARY, CLOAD, DLOAD, DSLOAD).

Adds BC to either global model or current step depending on context.
"""
function close_boundary_condition!(model, state)
    kind = Symbol(state.section.name)
    data = get_data(state)
    options = get_options(state)
    bc = BoundaryCondition(kind, data, options)
    if state.step === nothing
        push!(model.boundary_conditions, bc)
    else
        push!(state.step.boundary_conditions, bc)
    end
end

# =============================================================================
# Section Handlers - Output Requests
# =============================================================================

"""
    close_output_request!(model, state)

Close output request section (NODE PRINT, EL PRINT, NODE FILE, EL FILE).

Adds output request to current step.
"""
function close_output_request!(model, state)
    parts = split(state.section.name, " ")
    if length(parts) == 2
        kind, target = map(Symbol, parts)
    else
        kind = Symbol(parts[1])
        target = :UNKNOWN
    end

    data = length(state) > 0 ? get_data(state) : []
    options = get_options(state)
    request = OutputRequest(kind, data, options, target)

    if state.step !== nothing
        push!(state.step.output_requests, request)
    else
        @debug "Output request outside step - ignoring"
    end
end

"""
    close_output_definition!(model, state)

Close output definition section (NODE OUTPUT, ELEMENT OUTPUT within OUTPUT block).
"""
function close_output_definition!(model, state)
    # Similar to output_request but for OUTPUT, FIELD/HISTORY block
    parts = split(state.section.name, " ")
    kind = Symbol(join(parts, "_"))

    data = length(state) > 0 ? get_data(state) : []
    options = get_options(state)
    request = OutputRequest(kind, data, options, :FIELD)

    if state.step !== nothing
        push!(state.step.output_requests, request)
    end
end
