using Documenter, AbaqusReader

# Copy visualizer frontend to docs assets so it gets deployed to GitHub Pages
visualizer_src = joinpath(@__DIR__, "..", "visualizer", "frontend")
visualizer_dest = joinpath(@__DIR__, "src", "assets", "visualizer")

if isdir(visualizer_src)
  @info "Copying visualizer frontend from $visualizer_src to $visualizer_dest"
  mkpath(visualizer_dest)
  
  # Copy all frontend files
  for file in readdir(visualizer_src)
    src_file = joinpath(visualizer_src, file)
    dest_file = joinpath(visualizer_dest, file)
    if isfile(src_file)
      cp(src_file, dest_file; force=true)
      @info "  Copied $file"
    end
  end
else
  @warn "Visualizer frontend directory not found at $visualizer_src"
end

makedocs(modules=[AbaqusReader],
  format=Documenter.HTML(
    prettyurls=get(ENV, "CI", "false") == "true",
    canonical="https://ahojukka5.github.io/AbaqusReader.jl",
    assets=String["assets/custom.css"],
    collapselevel=1,
    footer="AbaqusReader.jl - Modern FEM mesh parser for Julia",
    edit_link="master",
    ansicolor=true,
  ),
  checkdocs=:exports,
  sitename="AbaqusReader.jl",
  authors="Jukka Aho and contributors",
  pages=[
    "Home" => "index.md",
    "Philosophy" => "philosophy.md",
    "Lessons Learned" => "lessons_learned.md",
    "Examples" => "examples.md",
    "Supported Elements" => "elements.md",
    "Element Database" => "element_database.md",
    "API Reference" => "api.md",
    "Contributing" => "contributing.md",
  ]
)

deploydocs(
  repo="github.com/ahojukka5/AbaqusReader.jl.git",
  devbranch="master",
  push_preview=true,
)
