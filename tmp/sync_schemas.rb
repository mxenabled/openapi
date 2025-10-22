#!/usr/bin/env ruby
# frozen_string_literal: true

# Dynamic Schema Synchronization Script
# Reads comparison report and adds all missing schemas from models.yaml
# Handles trailing spaces, preserves formatting, converts $ref

require 'json'

def main
  puts "=" * 70
  puts "Schema Synchronization: Dynamic Schema Addition"
  puts "=" * 70

  # Read the comparison diff JSON
  puts "\n[1/6] Reading comparison_diff.json..."
  diff = JSON.parse(File.read('tmp/comparison_diff.json'))

  # Get list of missing schemas
  missing_schemas = diff['missing_schemas'].map { |s| s['name'] }.sort
  
  if missing_schemas.empty?
    puts "✅ No missing schemas to add!"
    return 0
  end

  puts "Found #{missing_schemas.size} missing schemas in comparison report\n"
  missing_schemas.each_with_index do |schema, i|
    puts "  #{(i + 1).to_s.rjust(2)}. #{schema}"
  end

  # Read models.yaml as raw text
  puts "\n[2/6] Reading models.yaml..."
  models_content = File.read('openapi/models.yaml')
  puts "✅ Loaded models.yaml (#{models_content.lines.count} lines)"

  # Read mx_platform_api.yml
  puts "\n[3/6] Reading mx_platform_api.yml..."
  api_content = File.read('openapi/mx_platform_api.yml')
  
  # Check which schemas already exist (with proper indentation)
  existing_schemas = api_content.scan(/^    ([A-Z][A-Za-z0-9]+):/).flatten.uniq
  puts "✅ Found #{existing_schemas.size} existing schemas"

  # Track statistics
  added = []
  skipped = []
  not_found = []

  # Process each missing schema
  puts "\n[4/6] Extracting schemas from models.yaml..."
  missing_schemas.each do |schema_name|
    if existing_schemas.include?(schema_name)
      puts "  ⏭️  #{schema_name.ljust(40)} (already exists)"
      skipped << schema_name
      next
    end

    # Extract schema from models.yaml using regex
    # Pattern: schema_name at start of line with optional trailing space/colon
    # Capture all indented content (lines starting with 2+ spaces) until next schema
    pattern = /^#{Regexp.escape(schema_name)}:[ ]?\n((?:  .+\n)*)/
    match = models_content.match(pattern)

    unless match
      puts "  ❌ #{schema_name.ljust(40)} (not found in models.yaml)"
      not_found << schema_name
      next
    end

    schema_content = match[1]
    
    # Add 4 spaces of indentation (for components.schemas level)
    indented_content = schema_content.lines.map { |line| "    #{line}" }.join
    
    # Convert external $ref to internal format
    # Handles both quoted and unquoted refs
    indented_content.gsub!(/\$ref: ['"]?#\/([A-Za-z0-9_]+)['"]?/, '$ref: \'#/components/schemas/\1\'')
    
    # Build the complete schema YAML with schema name
    schema_yaml = "    #{schema_name}:\n#{indented_content}"
    
    puts "  ✅ #{schema_name.ljust(40)} (#{schema_content.lines.count} lines)"
    added << { name: schema_name, yaml: schema_yaml, lines: schema_content.lines.count }
  end

  # Summary of extraction phase
  puts "\n[5/6] Extraction Summary:"
  puts "  ✅ Added:     #{added.size}"
  puts "  ⏭️  Skipped:   #{skipped.size}"
  puts "  ❌ Not found: #{not_found.size}"

  if not_found.any?
    puts "\n  ⚠️  Schemas not found in models.yaml:"
    not_found.each { |s| puts "     - #{s}" }
  end

  if added.empty?
    puts "\n❌ No schemas to add! Exiting."
    return 1
  end

  # Find insertion point (before securitySchemes)
  puts "\n[6/6] Inserting schemas into mx_platform_api.yml..."
  insertion_pattern = /^  securitySchemes:\s*$/
  match = api_content.match(insertion_pattern)

  unless match
    puts "❌ ERROR: Could not find insertion point (securitySchemes:)"
    puts "   Expected pattern: '  securitySchemes:' at start of line"
    return 1
  end

  insertion_index = match.begin(0)
  insertion_line = api_content[0...insertion_index].count("\n") + 1

  puts "✅ Insertion point: line #{insertion_line} (before securitySchemes:)"

  # Insert all schemas at once
  new_schemas_yaml = added.map { |s| s[:yaml] }.join("\n")
  total_lines_added = added.sum { |s| s[:lines] + 1 } # +1 for schema name line
  
  api_content.insert(insertion_index, "#{new_schemas_yaml}\n")

  # Write back to file
  puts "✅ Writing updated mx_platform_api.yml..."
  File.write('openapi/mx_platform_api.yml', api_content)

  # Final summary
  puts "\n" + "=" * 70
  puts "✅ Schema Synchronization Complete!"
  puts "=" * 70
  puts "Schemas added:      #{added.size}"
  puts "Lines added:        ~#{total_lines_added}"
  puts "Schemas skipped:    #{skipped.size} (already exist)"
  puts "Schemas not found:  #{not_found.size}"
  puts "=" * 70
  
  if added.any?
    puts "\nAdded schemas:"
    added.each_with_index do |schema, i|
      puts "  #{(i + 1).to_s.rjust(2)}. #{schema[:name]} (#{schema[:lines]} lines)"
    end
  end

  puts "\n📋 Next Steps:"
  puts "  1. Review changes: git diff openapi/mx_platform_api.yml"
  puts "  2. Re-run comparison: ruby tmp/compare_openapi_specs.rb"
  puts "  3. Verify: ruby tmp/compare_openapi_specs.rb 2>&1 | grep 'Missing schemas:'"
  puts ""

  0
end

# Run the script
exit_code = main
exit(exit_code)
