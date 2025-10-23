#!/usr/bin/env ruby
require 'yaml'
require 'json'

puts "=" * 80
puts "PHASE 9: FINAL VALIDATION"
puts "=" * 80
puts ""

# Load files
puts "Loading files..."
source = YAML.unsafe_load_file('openapi/v20111101.yaml')
target = YAML.unsafe_load_file('openapi/mx_platform_api.yml')
models = YAML.unsafe_load_file('openapi/models.yaml')
parameters = YAML.unsafe_load_file('openapi/parameters.yaml')

puts "✓ All files loaded successfully"
puts ""

# Track validation results
issues = []
warnings = []

# 1. SCHEMA VALIDATION
puts "1. VALIDATING SCHEMAS"
puts "-" * 40

source_schemas = source.dig('components', 'schemas') || {}
target_schemas = target.dig('components', 'schemas') || {}

# Check schema count
puts "Schema counts:"
puts "  v20111101.yaml (models.yaml): #{models.keys.count}"
puts "  mx_platform_api.yml: #{target_schemas.keys.count}"

missing_schemas = models.keys - target_schemas.keys
extra_schemas = target_schemas.keys - models.keys

if missing_schemas.any?
  issues << "Missing #{missing_schemas.count} schemas: #{missing_schemas.join(', ')}"
  puts "  ❌ Missing schemas: #{missing_schemas.join(', ')}"
else
  puts "  ✓ No missing schemas"
end

if extra_schemas.any?
  issues << "Extra #{extra_schemas.count} schemas: #{extra_schemas.join(', ')}"
  puts "  ❌ Extra schemas: #{extra_schemas.join(', ')}"
else
  puts "  ✓ No extra schemas"
end

# Validate schema structures
puts "\nValidating schema structures..."
schema_field_mismatches = 0

models.each do |schema_name, schema_def|
  next unless target_schemas[schema_name]
  next unless schema_def['properties']
  
  source_props = schema_def['properties'].keys.sort
  target_props = (target_schemas[schema_name]['properties'] || {}).keys.sort
  
  if source_props != target_props
    schema_field_mismatches += 1
    missing = source_props - target_props
    extra = target_props - source_props
    
    if missing.any?
      issues << "#{schema_name}: missing fields #{missing.join(', ')}"
    end
    if extra.any?
      issues << "#{schema_name}: extra fields #{extra.join(', ')}"
    end
  end
end

if schema_field_mismatches > 0
  puts "  ❌ #{schema_field_mismatches} schemas have field mismatches"
else
  puts "  ✓ All schema structures match"
end

puts ""

# 2. PARAMETER VALIDATION
puts "2. VALIDATING PARAMETERS"
puts "-" * 40

target_params = target.dig('components', 'parameters') || {}

puts "Parameter counts:"
puts "  v20111101.yaml (parameters.yaml): #{parameters.keys.count}"
puts "  mx_platform_api.yml: #{target_params.keys.count}"

missing_params = parameters.keys - target_params.keys
extra_params = target_params.keys - parameters.keys

if missing_params.any?
  issues << "Missing #{missing_params.count} parameters: #{missing_params.join(', ')}"
  puts "  ❌ Missing parameters: #{missing_params.join(', ')}"
else
  puts "  ✓ No missing parameters"
end

if extra_params.any?
  issues << "Extra #{extra_params.count} parameters: #{extra_params.join(', ')}"
  puts "  ❌ Extra parameters: #{extra_params.join(', ')}"
else
  puts "  ✓ No extra parameters"
end

puts ""

# 3. PATH VALIDATION
puts "3. VALIDATING PATHS"
puts "-" * 40

source_paths = (source['paths'] || {}).keys.sort
target_paths = (target['paths'] || {}).keys.sort

puts "Path counts:"
puts "  v20111101.yaml: #{source_paths.count}"
puts "  mx_platform_api.yml: #{target_paths.count}"

missing_paths = source_paths - target_paths
extra_paths = target_paths - source_paths

if missing_paths.any?
  issues << "Missing #{missing_paths.count} paths"
  puts "  ❌ Missing paths:"
  missing_paths.each { |path| puts "    - #{path}" }
else
  puts "  ✓ No missing paths"
end

if extra_paths.any?
  issues << "Extra #{extra_paths.count} paths"
  puts "  ❌ Extra paths:"
  extra_paths.each { |path| puts "    - #{path}" }
else
  puts "  ✓ No extra paths"
end

# Validate operations per path
puts "\nValidating operations per path..."
operation_mismatches = 0

source_paths.each do |path|
  next unless target['paths'][path]
  
  source_ops = (source['paths'][path] || {}).keys.reject { |k| k.start_with?('$') || k == 'parameters' }.sort
  target_ops = (target['paths'][path] || {}).keys.reject { |k| k.start_with?('$') || k == 'parameters' }.sort
  
  if source_ops != target_ops
    operation_mismatches += 1
    missing = source_ops - target_ops
    extra = target_ops - source_ops
    
    if missing.any?
      issues << "#{path}: missing operations #{missing.join(', ')}"
    end
    if extra.any?
      issues << "#{path}: extra operations #{extra.join(', ')}"
    end
  end
end

if operation_mismatches > 0
  puts "  ❌ #{operation_mismatches} paths have operation mismatches"
else
  puts "  ✓ All path operations match"
end

puts ""

# 4. EXTERNAL REFERENCE CHECK
puts "4. CHECKING FOR EXTERNAL REFERENCES"
puts "-" * 40

yaml_content = File.read('openapi/mx_platform_api.yml')
external_refs = yaml_content.scan(/\$ref:\s*['"]\.\/schemas\//)

if external_refs.any?
  issues << "Found #{external_refs.count} external references"
  puts "  ❌ External references found: #{external_refs.count}"
else
  puts "  ✓ No external references (file is self-contained)"
end

puts ""

# 5. TAG VALIDATION
puts "5. VALIDATING TAGS"
puts "-" * 40

# Collect all tags used in paths
source_tags = []
target_tags = []

source['paths']&.each do |path, path_def|
  path_def.each do |method, op_def|
    next if method.start_with?('$') || method == 'parameters'
    next unless op_def.is_a?(Hash)
    source_tags.concat(op_def['tags'] || [])
  end
end

target['paths']&.each do |path, path_def|
  path_def.each do |method, op_def|
    next if method.start_with?('$') || method == 'parameters'
    next unless op_def.is_a?(Hash)
    target_tags.concat(op_def['tags'] || [])
  end
end

source_tags = source_tags.uniq.sort
target_tags = target_tags.uniq.sort

puts "Tag counts:"
puts "  v20111101.yaml: #{source_tags.count} unique tags"
puts "  mx_platform_api.yml: #{target_tags.count} unique tags"

# Check for generic tags
generic_tags = target_tags.select { |tag| tag == 'mx_platform' || tag.downcase.include?('platform') }

if generic_tags.any?
  warnings << "Found #{generic_tags.count} generic tags: #{generic_tags.join(', ')}"
  puts "  ⚠️  Generic tags found: #{generic_tags.join(', ')}"
else
  puts "  ✓ No generic tags"
end

missing_tags = source_tags - target_tags
extra_tags = target_tags - source_tags

if missing_tags.any?
  warnings << "Missing #{missing_tags.count} tags: #{missing_tags.join(', ')}"
  puts "  ⚠️  Missing tags: #{missing_tags.join(', ')}"
end

if extra_tags.any?
  warnings << "Extra #{extra_tags.count} tags: #{extra_tags.join(', ')}"
  puts "  ⚠️  Extra tags: #{extra_tags.join(', ')}"
end

puts ""

# 6. TYPE CONSISTENCY CHECK
puts "6. VALIDATING TYPE CONSISTENCY"
puts "-" * 40

type_mismatches = 0

models.each do |schema_name, schema_def|
  next unless target_schemas[schema_name]
  next unless schema_def['properties']
  
  schema_def['properties'].each do |field_name, field_def|
    target_field = target_schemas[schema_name].dig('properties', field_name)
    next unless target_field
    
    source_type = field_def['type']
    target_type = target_field['type']
    
    if source_type && target_type && source_type != target_type
      type_mismatches += 1
      issues << "Type mismatch: #{schema_name}.#{field_name} (source: #{source_type}, target: #{target_type})"
    end
  end
end

if type_mismatches > 0
  puts "  ❌ Found #{type_mismatches} type mismatches"
else
  puts "  ✓ All types match"
end

puts ""

# 7. FILE STRUCTURE VALIDATION
puts "7. VALIDATING FILE STRUCTURE"
puts "-" * 40

required_sections = ['openapi', 'info', 'servers', 'paths', 'components']
missing_sections = required_sections.select { |section| !target[section] }

if missing_sections.any?
  issues << "Missing required sections: #{missing_sections.join(', ')}"
  puts "  ❌ Missing sections: #{missing_sections.join(', ')}"
else
  puts "  ✓ All required sections present"
end

# Check components subsections
required_components = ['schemas', 'parameters', 'securitySchemes']
missing_components = required_components.select { |comp| !target.dig('components', comp) }

if missing_components.any?
  issues << "Missing component sections: #{missing_components.join(', ')}"
  puts "  ❌ Missing component sections: #{missing_components.join(', ')}"
else
  puts "  ✓ All component sections present"
end

puts ""

# FINAL SUMMARY
puts "=" * 80
puts "VALIDATION SUMMARY"
puts "=" * 80
puts ""

if issues.empty? && warnings.empty?
  puts "🎉 PERFECT! All validations passed with no issues or warnings."
  puts ""
  puts "✓ Schema parity: 100%"
  puts "✓ Parameter parity: 100%"
  puts "✓ Path parity: 100%"
  puts "✓ Type consistency: 100%"
  puts "✓ No external references"
  puts "✓ File structure complete"
  puts ""
  puts "mx_platform_api.yml is fully synchronized with v20111101.yaml"
  exit 0
elsif issues.empty?
  puts "✅ VALIDATION PASSED (with #{warnings.count} warnings)"
  puts ""
  puts "Critical Issues: 0"
  puts "Warnings: #{warnings.count}"
  puts ""
  puts "Warnings:"
  warnings.each { |w| puts "  ⚠️  #{w}" }
  puts ""
  exit 0
else
  puts "❌ VALIDATION FAILED"
  puts ""
  puts "Critical Issues: #{issues.count}"
  puts "Warnings: #{warnings.count}"
  puts ""
  
  if issues.any?
    puts "Critical Issues:"
    issues.each { |i| puts "  ❌ #{i}" }
    puts ""
  end
  
  if warnings.any?
    puts "Warnings:"
    warnings.each { |w| puts "  ⚠️  #{w}" }
    puts ""
  end
  
  puts "Please resolve critical issues before proceeding."
  exit 1
end
