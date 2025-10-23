#!/usr/bin/env ruby
require 'yaml'

puts "=" * 80
puts "FIXING PARAMETER SCHEMA DEFINITIONS"
puts "=" * 80
puts

# Load source parameters
params_source = YAML.unsafe_load_file('openapi/parameters.yaml')

# Parameters that need fixing based on validation errors
params_to_fix = {
  'userIsDisabled' => {
    'type' => 'boolean'
  },
  'topLevelCategoryGuidArray' => {
    'type' => 'array',
    'items' => { 'type' => 'string' }
  },
  'topLevelCategoryGuid' => {
    'type' => 'string'
  },
  'includes' => {
    'type' => 'string'
  },
  'categoryGuidQueryArray' => {
    'type' => 'array',
    'items' => { 'type' => 'string' }
  },
  'categoryGuidQuery' => {
    'type' => 'string'
  }
}

puts "Parameters to fix:"
params_to_fix.each do |name, schema|
  puts "  - #{name}: #{schema.inspect}"
end
puts

# Verify these exist in parameters.yaml
puts "Verifying parameters exist in source..."
params_to_fix.each do |name, _|
  if params_source[name]
    source_schema = params_source[name]['schema']
    puts "  ✓ #{name}: source has schema: #{source_schema.inspect}"
  else
    puts "  ✗ #{name}: NOT FOUND in parameters.yaml"
  end
end
puts

# Fix each parameter using yq
puts "Fixing parameters in mx_platform_api.yml..."
params_to_fix.each do |param_name, schema_def|
  puts "\nFixing #{param_name}..."
  
  # Add 'in: query' if missing
  cmd = "yq -i '.components.parameters.#{param_name}.in = \"query\"' openapi/mx_platform_api.yml"
  puts "  Setting in: #{cmd}"
  system(cmd)
  
  if schema_def['items']
    # Array type with items
    cmd = "yq -i '.components.parameters.#{param_name}.schema.type = \"#{schema_def['type']}\"' openapi/mx_platform_api.yml"
    puts "  Setting type: #{cmd}"
    system(cmd)
    
    cmd = "yq -i '.components.parameters.#{param_name}.schema.items.type = \"#{schema_def['items']['type']}\"' openapi/mx_platform_api.yml"
    puts "  Setting items.type: #{cmd}"
    system(cmd)
  else
    # Simple type
    cmd = "yq -i '.components.parameters.#{param_name}.schema.type = \"#{schema_def['type']}\"' openapi/mx_platform_api.yml"
    puts "  Setting type: #{cmd}"
    system(cmd)
  end
  
  puts "  ✓ Fixed #{param_name}"
end

puts
puts "=" * 80
puts "VALIDATION"
puts "=" * 80

# Verify fixes
mx_platform = YAML.unsafe_load_file('openapi/mx_platform_api.yml')
all_good = true

params_to_fix.each do |param_name, expected_schema|
  param_def = mx_platform['components']['parameters'][param_name]
  actual_schema = param_def['schema']
  
  # Check 'in' property
  if param_def['in'] != 'query'
    puts "  ✗ #{param_name}: missing 'in: query'"
    all_good = false
  end
  
  if actual_schema.nil? || actual_schema.empty?
    puts "  ✗ #{param_name}: schema is still empty"
    all_good = false
  elsif expected_schema['items']
    if actual_schema['type'] == expected_schema['type'] && 
       actual_schema['items'] && 
       actual_schema['items']['type'] == expected_schema['items']['type']
      puts "  ✓ #{param_name}: schema is correct (array with items)"
    else
      puts "  ✗ #{param_name}: schema mismatch"
      puts "    Expected: #{expected_schema.inspect}"
      puts "    Actual: #{actual_schema.inspect}"
      all_good = false
    end
  else
    if actual_schema['type'] == expected_schema['type']
      puts "  ✓ #{param_name}: schema is correct"
    else
      puts "  ✗ #{param_name}: schema mismatch"
      puts "    Expected: #{expected_schema.inspect}"
      puts "    Actual: #{actual_schema.inspect}"
      all_good = false
    end
  end
end

puts
if all_good
  puts "🎉 All parameter schemas fixed successfully!"
else
  puts "⚠️  Some parameters still have issues"
  exit 1
end
