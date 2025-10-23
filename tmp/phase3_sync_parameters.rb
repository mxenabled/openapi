#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Parameter Synchronization Script
# =================================
# Synchronizes parameters between source files and consolidated OpenAPI spec
#
# USAGE:
#   ruby tmp/sync_parameters.rb [params_file] [api_file] [comparison_file]
#
# ARGUMENTS:
#   params_file      - Source parameters file (default: openapi/parameters.yaml)
#   api_file         - Target OpenAPI file (default: openapi/mx_platform_api.yml)
#   comparison_file  - JSON diff file (default: tmp/comparison_diff.json)
#
# EXAMPLES:
#   # Current version (uses defaults)
#   ruby tmp/sync_parameters.rb
#
#   # Future version v20250224
#   ruby tmp/sync_parameters.rb \
#     openapi/parameters.yaml \
#     openapi/mx_platform_api_v20250224.yml \
#     tmp/comparison_diff_v20250224.json
#
# PREREQUISITES:
#   - comparison_diff.json must exist (run compare_openapi_specs.rb first)
#   - Source parameters.yaml must exist
#   - Target API file must have 'components:' and 'securitySchemes:' or 'paths:' sections
#
# OUTPUT:
#   - Creates components.parameters section if missing (before securitySchemes)
#   - Adds missing parameters from comparison
#   - Removes extra parameters from comparison
#   - Converts inline parameter definitions to $ref
#   - Modifies api_file in place
#
# NOTES:
#   - Phase 3a: Adds parameters to components.parameters library
#   - Phase 3b: Converts ~352 inline parameters to $ref (atomic operation)
#   - Typos fixed before Phase 3: records_per_age → records_per_page, microdeposit_guid → micro_deposit_guid
#   - Unmatchable parameters from extra paths (e.g., tax_document_guid) removed in Phase 6
#   - Net effect: Typically reduces file size by 1000-2000 lines

require 'json'
require 'yaml'
require 'set'

# ============================================================================
# CONFIGURATION
# ============================================================================

comparison_file = ARGV[2] || 'tmp/comparison_diff.json'
params_file = ARGV[0] || 'openapi/parameters.yaml'
api_file = ARGV[1] || 'openapi/mx_platform_api.yml'

# ============================================================================
# LOAD FILES
# ============================================================================

puts "Reading comparison data from: #{comparison_file}"
comparison_data = JSON.parse(File.read(comparison_file))

puts "Loading parameters from: #{params_file}"
params_content = File.read(params_file)
params_source = YAML.unsafe_load_file(params_file)  # Also parse for property access

puts "Loading API file: #{api_file}"
api_content = File.read(api_file)

# ============================================================================
# EXTRACT DIFFERENCES
# ============================================================================

missing_params = comparison_data['missing_parameters'] || []
extra_params = comparison_data['extra_parameters_in_mx'] || []

puts "\nFound:"
puts "  - #{missing_params.length} parameters to add"
puts "  - #{extra_params.length} parameters to remove"

# Track modifications
modifications = {
  added: [],
  removed: [],
  skipped: []
}

# ============================================================================
# PART 1: ADD MISSING PARAMETERS
# ============================================================================

if missing_params.any?
  puts "\nAdding #{missing_params.length} missing parameters..."
  
  # Check if parameters section exists
  has_params_section = api_content =~ /^  parameters:\s*\n/
  
  # If no parameters section, create it before securitySchemes (or before paths if no securitySchemes)
  unless has_params_section
    puts "  Creating parameters section..."
    
    # Try to find securitySchemes first
    security_match = api_content.match(/^  (securitySchemes:)/)
    
    if security_match
      insert_pos = security_match.begin(0)
      api_content.insert(insert_pos, "  parameters:\n")
      puts "  ✅ Created parameters section before securitySchemes"
    else
      # Fallback: insert before paths
      paths_match = api_content.match(/^(paths:)/)
      
      if paths_match
        insert_pos = paths_match.begin(0)
        api_content.insert(insert_pos, "  parameters:\n")
        puts "  ✅ Created parameters section before paths"
      else
        puts "  ⚠️  Could not find securitySchemes or paths section"
        puts "Aborting."
        exit 1
      end
    end
  end
  
  # Now add each parameter
  missing_params.each do |param_info|
    param_name = param_info['name']
    
    # Load the parameter definition from source using YAML parser
    # This ensures we get the complete, parsed structure
    unless params_source[param_name]
      puts "  ⚠️  Could not find parameter definition in parameters.yaml: #{param_name}"
      modifications[:skipped] << param_name
      next
    end
    
    source_param = params_source[param_name]
    
    # Build parameter definition using yq commands for each property
    # This ensures all properties are captured, including multi-line descriptions
    properties_to_add = ['name', 'description', 'in', 'required', 'example']
    
    puts "  Adding parameter: #{param_name}"
    
    # First, create the parameter key in components.parameters
    cmd = "yq -i '.components.parameters.#{param_name} = {}' #{api_file}"
    system(cmd)
    
    # Add each property from source
    properties_to_add.each do |prop|
      next unless source_param[prop]
      
      value = source_param[prop]
      
      case value
      when String
        # Escape for shell - use printf style to handle special chars
        escaped_value = value.gsub("'", "'\\''")
        cmd = "yq -i '.components.parameters.#{param_name}.#{prop} = \"#{escaped_value}\"' #{api_file}"
        system(cmd)
      when TrueClass, FalseClass
        cmd = "yq -i '.components.parameters.#{param_name}.#{prop} = #{value}' #{api_file}"
        system(cmd)
      end
    end
    
    # Handle schema property (it's an object)
    if source_param['schema']
      schema = source_param['schema']
      
      if schema['type']
        cmd = "yq -i '.components.parameters.#{param_name}.schema.type = \"#{schema['type']}\"' #{api_file}"
        system(cmd)
      end
      
      # Handle array items
      if schema['items'] && schema['items']['type']
        cmd = "yq -i '.components.parameters.#{param_name}.schema.items.type = \"#{schema['items']['type']}\"' #{api_file}"
        system(cmd)
      end
    end
    
    # Validate that all required properties were added
    required_props = ['in', 'name', 'schema']
    missing_props = required_props.select { |prop| !source_param[prop.to_s] }
    
    if missing_props.any?
      puts "  ⚠️  Parameter #{param_name} is missing required properties in source: #{missing_props.join(', ')}"
    end
    
    modifications[:added] << param_name
    puts "  ✅ Added: #{param_name} with complete definition"
  end
end

# ============================================================================
# PART 2: REMOVE EXTRA PARAMETERS
# ============================================================================

if extra_params.any?
  puts "\nRemoving #{extra_params.length} extra parameters..."
  
  extra_params.each do |param_info|
    param_name = param_info['name']
    
    # Pattern to match parameter in components.parameters section
    # Parameters are at 4-space indent, content at 6-space indent
    removal_pattern = /^    #{Regexp.escape(param_name)}:\s*\n((?:      .+\n)*)/
    
    if api_content.match(removal_pattern)
      api_content.gsub!(removal_pattern, '')
      modifications[:removed] << param_name
      puts "  ✅ Removed parameter: #{param_name}"
    else
      puts "  ⚠️  Could not find parameter to remove: #{param_name}"
    end
  end
end

# ============================================================================
# PART 3: CONVERT INLINE PARAMETERS TO $REF
# ============================================================================

puts "\nConverting inline parameters to $ref..."

# Build a map of parameter name (from 'name:' field) to parameter key
param_name_to_key = {}

# Extract all parameter keys and their 'name:' values from components.parameters
params_section_match = api_content.match(/^  parameters:\s*\n(.*?)^  \w+:/m)
if params_section_match
  params_section_content = params_section_match[1]
  
  # Match each parameter block
  params_section_content.scan(/^    (\w+):\s*\n((?:      .+\n)*)/) do |param_key, param_content|
    name_match = param_content.match(/name:\s+(\S+)/)
    if name_match
      param_name = name_match[1]
      param_name_to_key[param_name] = param_key
    end
  end
end

puts "  Found #{param_name_to_key.size} parameters available for conversion"

# Track conversions
conversions = {
  converted: Set.new,
  not_found: Set.new,
  replacements: 0
}

# Use gsub to replace inline parameter blocks with $ref
# Match: "        - " followed by properties (not "$ref:")
# More precise: only match lines that are parameter properties (description, in, name, example, required, schema)
api_content.gsub!(/^        - (description|in|name|example|required|schema):.*?\n((?:          .*?\n)*?)(?=^        - |^      \w+:|\z)/m) do |match|
  # Extract name field from this parameter block
  name_match = match.match(/name:\s+(\S+)/)
  
  if name_match
    param_name = name_match[1]
    param_key = param_name_to_key[param_name]
    
    if param_key
      # Replace with $ref
      conversions[:converted] << param_name
      conversions[:replacements] += 1
      "        - $ref: '#/components/parameters/#{param_key}'\n"
    else
      # Keep inline
      conversions[:not_found] << param_name
      match
    end
  else
    # No name field, keep as-is
    match
  end
end

puts "  ✅ Converted #{conversions[:converted].size} unique parameters to $ref"
puts "  📊 Total replacements: #{conversions[:replacements]}"
if conversions[:not_found].any?
  puts "  ⚠️  #{conversions[:not_found].size} parameters not found in components (kept inline)"
  puts "     Examples: #{conversions[:not_found].to_a.first(5).join(', ')}"
end

modifications[:converted] = conversions[:converted].size
modifications[:not_found] = conversions[:not_found].size

# ============================================================================
# WRITE UPDATED FILE
# ============================================================================

puts "\nWriting changes to: #{api_file}"
File.write(api_file, api_content)

# ============================================================================
# SUMMARY
# ============================================================================

puts "\n" + "="*60
puts "Parameter Synchronization Complete"
puts "="*60
puts "Phase 3a - Library Creation:"
puts "  Parameters added: #{modifications[:added].length}"
puts "  Parameters removed: #{modifications[:removed].length}"
puts "  Parameters skipped: #{modifications[:skipped].length}"
puts "\nPhase 3b - Inline Conversion:"
puts "  Converted to $ref: #{modifications[:converted] || 0}"
puts "  Not found (kept inline): #{modifications[:not_found] || 0}"

if modifications[:skipped].any?
  puts "\nSkipped parameters (not found in source):"
  modifications[:skipped].each { |name| puts "  - #{name}" }
end

puts "\n✅ Successfully updated #{api_file}"
puts "\nNext steps:"
puts "1. Review changes: git diff #{api_file}"
puts "2. Verify line count: wc -l #{api_file}"
puts "3. Validate: ruby tmp/compare_openapi_specs.rb | grep -i parameter"
puts "4. Test: redocly preview-docs #{api_file}"
