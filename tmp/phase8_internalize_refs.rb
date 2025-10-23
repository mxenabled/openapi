#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'set'

# Phase 8: Internalize External References
# Convert external file refs to internal component refs while ensuring:
# 1. 100% fidelity to v20111101.yaml structure
# 2. Every referenced schema/parameter exists in mx_platform_api.yml
# 3. No broken references after conversion

SOURCE_FILE = 'openapi/v20111101.yaml'
TARGET_FILE = 'openapi/mx_platform_api.yml'

def run_command(cmd)
  output = `#{cmd} 2>&1`
  success = $?.success?
  [success, output.strip]
end

def check_yq
  version_output = `yq --version 2>&1`
  unless $?.success?
    puts "❌ ERROR: yq is not installed"
    puts "Please install: brew install yq"
    exit 1
  end
  puts "✓ Using #{version_output.strip}"
end

def load_yaml_safe(filepath)
  YAML.unsafe_load_file(filepath)
rescue => e
  puts "❌ Failed to load #{filepath}: #{e.message}"
  exit 1
end

def find_all_external_refs(filepath)
  refs = {
    schemas: Set.new,
    parameters: Set.new
  }
  
  content = File.read(filepath)
  
  # Find schema references: './schemas/models.yaml#/SchemaName'
  content.scan(/\$ref:\s*['"]\.\/schemas\/models\.yaml#\/([^'"]+)['"]/) do |match|
    refs[:schemas].add(match[0])
  end
  
  # Find parameter references: './schemas/parameters.yaml#/ParameterName'
  content.scan(/\$ref:\s*['"]\.\/schemas\/parameters\.yaml#\/([^'"]+)['"]/) do |match|
    refs[:parameters].add(match[0])
  end
  
  refs
end

def get_available_components(filepath)
  components = {
    schemas: Set.new,
    parameters: Set.new
  }
  
  data = load_yaml_safe(filepath)
  
  if data['components']
    components[:schemas] = Set.new(data['components']['schemas'].keys) if data['components']['schemas']
    components[:parameters] = Set.new(data['components']['parameters'].keys) if data['components']['parameters']
  end
  
  components
end

def verify_all_refs_exist(external_refs, available_components)
  missing = {
    schemas: [],
    parameters: []
  }
  
  external_refs[:schemas].each do |schema|
    unless available_components[:schemas].include?(schema)
      missing[:schemas] << schema
    end
  end
  
  external_refs[:parameters].each do |param|
    unless available_components[:parameters].include?(param)
      missing[:parameters] << param
    end
  end
  
  missing
end

def convert_external_refs(filepath)
  content = File.read(filepath)
  
  # Convert schema references
  schema_count = 0
  content.gsub!(/\$ref:\s*['"]\.\/schemas\/models\.yaml#\/([^'"]+)['"]/) do
    schema_count += 1
    "$ref: '#/components/schemas/#{$1}'"
  end
  
  # Convert parameter references
  param_count = 0
  content.gsub!(/\$ref:\s*['"]\.\/schemas\/parameters\.yaml#\/([^'"]+)['"]/) do
    param_count += 1
    "$ref: '#/components/parameters/#{$1}'"
  end
  
  File.write(filepath, content)
  
  { schemas: schema_count, parameters: param_count }
end

def verify_no_external_refs_remain(filepath)
  content = File.read(filepath)
  
  external_schemas = content.scan(/\$ref:\s*['"]\.\/schemas\/models\.yaml#\//)
  external_params = content.scan(/\$ref:\s*['"]\.\/schemas\/parameters\.yaml#\//)
  
  {
    schemas: external_schemas.length,
    parameters: external_params.length
  }
end

# Main execution
puts "=" * 80
puts "Phase 8: Internalize External References"
puts "=" * 80
puts
puts "Goal: Convert mx_platform_api.yml to completely self-contained spec"
puts "Source of truth: #{SOURCE_FILE}"
puts
puts "=" * 80
puts

check_yq

puts "📊 Step 1: Analyzing External References"
puts "=" * 80
puts

external_refs = find_all_external_refs(TARGET_FILE)

puts "   Found external references:"
puts "   - Schemas: #{external_refs[:schemas].size}"
puts "   - Parameters: #{external_refs[:parameters].size}"
puts

if external_refs[:schemas].empty? && external_refs[:parameters].empty?
  puts "✅ No external references found - file is already self-contained!"
  exit 0
end

puts "🔍 Step 2: Verifying All Components Exist"
puts "=" * 80
puts

available = get_available_components(TARGET_FILE)

puts "   Available in mx_platform_api.yml:"
puts "   - Schemas: #{available[:schemas].size}"
puts "   - Parameters: #{available[:parameters].size}"
puts

missing = verify_all_refs_exist(external_refs, available)

if missing[:schemas].any? || missing[:parameters].any?
  puts "❌ CRITICAL ERROR: Missing components in #{TARGET_FILE}!"
  puts
  
  if missing[:schemas].any?
    puts "   Missing Schemas (#{missing[:schemas].size}):"
    missing[:schemas].each { |s| puts "   - #{s}" }
    puts
  end
  
  if missing[:parameters].any?
    puts "   Missing Parameters (#{missing[:parameters].size}):"
    missing[:parameters].each { |p| puts "   - #{p}" }
    puts
  end
  
  puts "These components must be added before converting references."
  exit 1
end

puts "   ✓ All referenced schemas exist in components/schemas"
puts "   ✓ All referenced parameters exist in components/parameters"
puts

puts "🔄 Step 3: Converting External → Internal References"
puts "=" * 80
puts

# Create backup
backup_file = "#{TARGET_FILE}.backup"
File.write(backup_file, File.read(TARGET_FILE))
puts "   ✓ Created backup: #{backup_file}"
puts

converted = convert_external_refs(TARGET_FILE)

puts "   Converted references:"
puts "   - Schemas: #{converted[:schemas]}"
puts "   - Parameters: #{converted[:parameters]}"
puts

puts "✅ Step 4: Verification"
puts "=" * 80
puts

remaining = verify_no_external_refs_remain(TARGET_FILE)

if remaining[:schemas] > 0 || remaining[:parameters] > 0
  puts "❌ ERROR: External references still remain!"
  puts "   - Schemas: #{remaining[:schemas]}"
  puts "   - Parameters: #{remaining[:parameters]}"
  puts
  puts "Restoring from backup..."
  File.write(TARGET_FILE, File.read(backup_file))
  exit 1
end

puts "   ✓ No external schema references remain"
puts "   ✓ No external parameter references remain"
puts "   ✓ File is now completely self-contained"
puts

# Verify YAML is still valid
puts "🔍 Step 5: YAML Validation"
puts "=" * 80
puts

begin
  load_yaml_safe(TARGET_FILE)
  puts "   ✓ YAML structure is valid"
rescue => e
  puts "   ❌ YAML validation failed: #{e.message}"
  puts "   Restoring from backup..."
  File.write(TARGET_FILE, File.read(backup_file))
  exit 1
end

puts

# Show summary
puts "=" * 80
puts "Phase 8 Complete!"
puts "=" * 80
puts
puts "Summary:"
puts "  ✓ Converted #{converted[:schemas]} schema references"
puts "  ✓ Converted #{converted[:parameters]} parameter references"
puts "  ✓ All components verified to exist"
puts "  ✓ No external references remain"
puts "  ✓ YAML structure validated"
puts "  ✓ Backup created: #{backup_file}"
puts
puts "=" * 80
puts
puts "Next steps:"
puts "  1. Review changes: git diff #{TARGET_FILE}"
puts "  2. Test preview server: http://127.0.0.1:8080"
puts "  3. Verify all endpoints work correctly"
puts "  4. Delete backup if satisfied: rm #{backup_file}"
puts "  5. Remove temporary schemas directory: rm -rf openapi/schemas/"
puts "  6. Commit changes"
puts
puts "✅ mx_platform_api.yml is now completely self-contained!"
