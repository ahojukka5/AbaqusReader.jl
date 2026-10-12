"""
    parse_keyword(line; uppercase_keyword=true) -> Keyword

Parse a keyword line into structured Keyword object.

Extracts keyword name and options from lines like:
- `*MATERIAL, NAME=STEEL`
- `*STEP, NLGEOM=YES, INC=100`

# Arguments
- `line`: Keyword line starting with "*"
- `uppercase_keyword`: Whether to convert keyword and option names to uppercase

# Returns
Keyword object with name and options vector.
"""
function parse_keyword(line; uppercase_keyword=true)
    args = split(line, ",")
    args = map(String, map(strip, args))
    keyword_name = strip(args[1], '*')
    if uppercase_keyword
        keyword_name = uppercase(keyword_name)
    end
    keyword = Keyword(keyword_name, [])
    for option in args[2:end]
        pair = map(String, split(option, "="))
        if uppercase_keyword
            pair[1] = uppercase(pair[1])
        end
        if length(pair) == 1
            push!(keyword.options, pair[1])
        elseif length(pair) == 2
            push!(keyword.options, pair[1] => pair[2])
        else
            error("Keyword failure: $line, $option, $pair")
        end
    end
    return keyword
end

"""
    is_new_section(line::AbstractString) -> Bool

Check if line starts a new keyword section.

Returns true for keyword lines (single asterisk) and false for comments/data.
"""
function is_new_section(line::AbstractString)
    return is_keyword(line)
end

"""
Set of recognized ABAQUS keywords that the parser can handle.

Keywords not in this set will be ignored with a warning.
"""
const RECOGNIZED_KEYWORDS = Set([
    "NODE",
    "ELEMENT",
    "NSET",
    "ELSET",
    "SURFACE",
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
    is_abaqus_keyword_registered(keyword::String) -> Bool

Check if a keyword is recognized by the parser.
"""
function is_abaqus_keyword_registered(keyword::String)
    return keyword in RECOGNIZED_KEYWORDS
end
