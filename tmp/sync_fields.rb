#!/usr/bin/env ruby
# frozen_string_literal: true

# Dynamic Field Synchronization Script
# Adds missing fields AND removes extra fields to achieve parity with models.yaml
# Reusable for any documentation version
#
# Usage:
#   ruby tmp/sync_fields.rb
#   ruby tmp/sync_fields.rb models_v20250224.yaml mx_platform_api.yml

require 'json'

def main
  # Allow file paths to be overridden via command line arguments
  models_file = ARGV[0] || 'openapi/models.yaml'
  api_file = ARGV[1] || 'openapi/mx_platform_api.yml'
  diff_file = ARGV[2] || 'tmp/comparison_diff.json'
  
  puts "=" * 70
  puts "Field Synchronization: Add Missing & Remove Extra Fields"
  puts "=" * 70

  # Read the comparison diff JSON
  puts "\n[1/7] Reading #{diff_file}..."
  diff = JSON.parse(File.read(diff_file))

  # Get schemas with missing fields
  missing_fields_by_schema = diff['missing_fields_in_schemas'] || {}
  schemas_with_missing = missing_fields_by_schema.select { |k,v| v.is_a?(Array) && v.any? }.keys.sort
  
  # Get schemas with extra fields
  extra_fields_by_schema = diff['extra_fields_in_schemas'] || {}
  schemas_with_extra = extra_fields_by_schema.select { |k,v| v.is_a?(Array) && v.any? }.keys.sort

  # Combined list of schemas to modify
  all_schemas_to_modify = (schemas_with_missing + schemas_with_extra).uniq.sort

  if all_schemas_to_modify.empty?
    puts "✅ No fields to add or remove!"
    return 0
  end

  puts "Schemas with missing fields: #{schemas_with_missing.size}"
  puts "Schemas with extra fields:   #{schemas_with_extra.size}"
  puts "Total schemas to modify:     #{all_schemas_to_modify.size}\n"

  # Read source files
  puts "\n[2/7] Reading source files..."
  models_content = File.read(models_file)
  api_content = File.read(api_file)
  puts "✅ Loaded #{models_file} and #{api_file}"

  # Track statistics
  stats = {
    schemas_modified: 0,
    fields_added: 0,
    fields_removed: 0,
    schemas_skipped: 0
  }

  puts "\n[3/7] Processing schemas..."
  
  all_schemas_to_modify.each do |schema_name|
    missing_fields = missing_fields_by_schema[schema_name] || []
    extra_fields = extra_fields_by_schema[schema_name] || []
    
    next if missing_fields.empty? && extra_fields.empty?

    puts "\n  📝 #{schema_name}"
    puts "     Missing: #{missing_fields.size} fields" if missing_fields.any?
    puts "     Extra:   #{extra_fields.size} fields" if extra_fields.any?

    # Find the schema in mx_platform_api.yml (with optional trailing space)
    schema_pattern = /^    #{Regexp.escape(schema_name)}:[ ]?\n((?:      .+\n)*)/
    schema_match = api_content.match(schema_pattern)

    unless schema_match
      puts "     ❌ Schema not found in mx_platform_api.yml"
      stats[:schemas_skipped] += 1
      next
    end

    schema_start = schema_match.begin(0)
    schema_end = schema_match.end(0)
    schema_content = schema_match[1]

    modified_content = schema_content.dup
    schema_modified = false

    # REMOVE extra fields
    extra_fields.each do |field_info|
      field_name = field_info['field']
      
      # Pattern to match the field and all its content (8-space indent for fields under properties)
      field_pattern = /^        #{Regexp.escape(field_name)}:\s*\n((?:          .+\n)*)/
      
      if modified_content.match(field_pattern)
        modified_content.gsub!(field_pattern, '')
        puts "     ❌ Removed: #{field_name}"
        stats[:fields_removed] += 1
        schema_modified = true
      end
    end

    # ADD missing fields
    missing_fields.each do |field_info|
      field_name = field_info['field']
      
      # Check if field already exists in target schema (8-space indent under properties)
      existing_field_pattern = /^        #{Regexp.escape(field_name)}:\s*\n/
      if modified_content.match(existing_field_pattern)
        puts "     ⚠️  #{field_name}: Already exists (skipping)"
        next
      end
      
      # Extract field from models.yaml
      # Find the schema first
      source_schema_pattern = /^#{Regexp.escape(schema_name)}:[ ]?\n((?:  .+\n)*)/
      source_schema_match = models_content.match(source_schema_pattern)
      
      unless source_schema_match
        puts "     ⚠️  #{field_name}: Schema not found in models.yaml"
        next
      end

      source_schema_content = source_schema_match[1]
      
      # Extract the field from source schema (2-space indent in models.yaml)
      field_pattern = /^  properties:\n((?:    .+\n)*?)(?:^    #{Regexp.escape(field_name)}:\s*\n((?:      .+\n)*))/m
      
      # Try to find the field within properties section
      if source_schema_content =~ /^  properties:\n((?:    .+\n)*)/m
        properties_section = $1
        
        # Extract just this field
        field_match = properties_section.match(/^    #{Regexp.escape(field_name)}:\s*\n((?:      .+\n)*)/)
        
        if field_match
          field_content = field_match[0]
          
          # Add 4 more spaces for mx_platform_api.yml (8 spaces total for fields under properties)
          indented_field = field_content.lines.map { |line| "    #{line}" }.join
          
          # Convert external $ref to internal
          indented_field.gsub!(/\$ref: ['"]?#\/([A-Za-z0-9_]+)['"]?/, '$ref: \'#/components/schemas/\1\'')
          
          # Find where to insert (after properties: line, before next field or end)
          # Insert at end of properties section (looking for 8-space indented fields)
          if modified_content =~ /^      properties:\n((?:        .+\n)*)/
            properties_end = $~.end(1)
            modified_content.insert(properties_end, indented_field)
            puts "     ✅ Added: #{field_name}"
            stats[:fields_added] += 1
            schema_modified = true
          else
            puts "     ⚠️  #{field_name}: Could not find properties section"
          end
        else
          puts "     ⚠️  #{field_name}: Not found in source schema"
        end
      end
    end

    if schema_modified
      # Replace the schema in the API file
      new_schema = "    #{schema_name}:\n#{modified_content}"
      api_content[schema_start...schema_end] = new_schema
      stats[:schemas_modified] += 1
    end
  end

  puts "\n[4/7] Writing updated #{api_file}..."
  File.write(api_file, api_content)
  puts "✅ File updated"

  # Summary
  puts "\n" + "=" * 70
  puts "✅ Field Synchronization Complete!"
  puts "=" * 70
  puts "Schemas modified:    #{stats[:schemas_modified]}"
  puts "Fields added:        #{stats[:fields_added]}"
  puts "Fields removed:      #{stats[:fields_removed]}"
  puts "Schemas skipped:     #{stats[:schemas_skipped]}"
  puts "=" * 70

  puts "\n📋 Next Steps:"
  puts "  1. Review changes: git diff #{api_file}"
  puts "  2. Re-run comparison: ruby tmp/compare_openapi_specs.rb"
  puts "  3. Verify field sync:"
  puts "     ruby tmp/compare_openapi_specs.rb 2>&1 | grep -E 'Missing.*Fields|Extra.*Fields'"
  puts ""
  puts "💡 For future versions:"
  puts "   ruby tmp/sync_fields.rb models_v20250224.yaml mx_platform_api.yml"
  puts ""

  0
end

# Run the script
exit_code = main
exit(exit_code)
