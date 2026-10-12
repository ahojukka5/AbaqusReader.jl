#!/usr/bin/env julia

"""
    scripts/codecov.jl

Generate and display code coverage report for AbaqusReader.jl.

Usage:
    julia --project=. scripts/codecov.jl

This script:
1. Runs the test suite with coverage enabled
2. Processes coverage data files
3. Generates a detailed coverage report with file-by-file breakdown
4. Displays overall coverage percentage

The script uses colored output with emojis to indicate coverage levels:
- ✅ Green: >= 80% coverage (good)
- ⚠️  Yellow: 60-79% coverage (needs improvement)
- ❌ Red: < 60% coverage (critical)
"""

using Pkg
using Coverage
using Printf

println("="^80)
println("📊 AbaqusReader.jl Code Coverage Report")
println("="^80)
println()

# Run tests with coverage
println("🧪 Running tests with coverage enabled...")
println()
Pkg.test(coverage=true)
println()

# Process coverage files
println("📁 Processing coverage data...")
coverage = process_folder("src")

# Calculate coverage by file
println()
println("="^80)
println("📈 Coverage by File")
println("="^80)
println()

coverage_by_file = Dict{String,Tuple{Int,Int}}()
for item in coverage
    file = item.filename
    if !haskey(coverage_by_file, file)
        coverage_by_file[file] = (0, 0)
    end
    covered, total = coverage_by_file[file]
    if item.coverage !== nothing && item.coverage > 0
        coverage_by_file[file] = (covered + 1, total + 1)
    elseif item.coverage == 0
        coverage_by_file[file] = (covered, total + 1)
    end
end

# Sort files by name
sorted_files = sort(collect(keys(coverage_by_file)))

for file in sorted_files
    covered, total = coverage_by_file[file]
    if total > 0
        percentage = round((covered / total) * 100, digits=1)

        # Color coding
        if percentage >= 80
            emoji = "✅"
            color = :green
        elseif percentage >= 60
            emoji = "⚠️ "
            color = :yellow
        else
            emoji = "❌"
            color = :red
        end

        # Display shortened file path
        short_file = replace(file, r"^.*?/src/" => "src/")
        printstyled("$emoji  ", color=color)
        printstyled(@sprintf("%-50s", short_file), color=:normal)
        printstyled(@sprintf("%6.1f%%", percentage), color=color)
        printstyled(@sprintf("  (%3d/%3d lines)\n", covered, total), color=:light_black)
    end
end

# Calculate overall coverage
total_covered = sum(item[1] for item in values(coverage_by_file))
total_lines = sum(item[2] for item in values(coverage_by_file))
overall_percentage = total_lines > 0 ? round((total_covered / total_lines) * 100, digits=2) : 0.0

println()
println("="^80)
println("🎯 Overall Coverage")
println("="^80)
println()

if overall_percentage >= 80
    printstyled("✅ ", color=:green, bold=true)
    printstyled(@sprintf("%.2f%%", overall_percentage), color=:green, bold=true)
elseif overall_percentage >= 60
    printstyled("⚠️  ", color=:yellow, bold=true)
    printstyled(@sprintf("%.2f%%", overall_percentage), color=:yellow, bold=true)
else
    printstyled("❌ ", color=:red, bold=true)
    printstyled(@sprintf("%.2f%%", overall_percentage), color=:red, bold=true)
end
printstyled(@sprintf(" (%d/%d lines covered)\n", total_covered, total_lines), color=:normal)

println()
println("="^80)
println("Legend:")
println("  ✅  >= 80%  (Good)")
println("  ⚠️   60-79% (Needs improvement)")
println("  ❌  < 60%   (Critical)")
println("="^80)
println()

# Generate LCOV file for external tools
println("💾 Generating LCOV file...")
LCOV.writefile("coverage.info", coverage)
println("   Wrote coverage.info")
println()

println("✨ Coverage report complete!")
println()
