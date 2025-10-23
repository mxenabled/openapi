#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 7: Fix Type Mismatches
# Change 3 fields from integer to number to match models.yaml

TARGET_FILE = 'openapi/mx_platform_api.yml'

TYPE_FIXES = [
  {
    schema: 'MicrodepositVerifyRequest',
    field: 'deposit_amount_1',
    current: 'integer',
    correct: 'number',
    reason: 'Deposits can be fractional (cents)'
  },
  {
    schema: 'MicrodepositVerifyRequest',
    field: 'deposit_amount_2',
    current: 'integer',
    correct: 'number',
    reason: 'Deposits can be fractional (cents)'
  },
  {
    schema: 'MonthlyCashFlowResponse',
    field: 'estimated_goals_contribution',
    current: 'integer',
    correct: 'number',
    reason: 'Financial amounts should support decimals'
  }
].freeze

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

def fix_type(schema, field, new_type)
  # Use yq to change the type field
  escaped_schema = schema.gsub("'", "'\\''")
  escaped_field = field.gsub("'", "'\\''")
  
  cmd = "yq eval '.components.schemas.\"#{escaped_schema}\".properties.\"#{escaped_field}\".type = \"#{new_type}\"' -i #{TARGET_FILE}"
  
  success, output = run_command(cmd)
  
  unless success
    puts "❌ Failed to update #{schema}.#{field}"
    puts output
    return false
  end
  
  true
end

# Main execution
puts "=" * 80
puts "Phase 7: Fix Type Mismatches"
puts "=" * 80
puts
puts "This will change 3 fields from integer to number to match models.yaml"
puts
puts "=" * 80
puts

check_yq

fix_count = 0
fix_errors = 0

TYPE_FIXES.each do |fix|
  print "   Fixing #{fix[:schema]}.#{fix[:field]} (#{fix[:current]} → #{fix[:correct]})... "
  
  if fix_type(fix[:schema], fix[:field], fix[:correct])
    puts "✓"
    fix_count += 1
  else
    puts "✗"
    fix_errors += 1
  end
end

puts
puts "=" * 80
puts "Phase 7 Summary:"
puts "  ✓ Types fixed: #{fix_count}"
puts "  ✗ Errors: #{fix_errors}" if fix_errors > 0
puts "=" * 80
puts

if fix_errors > 0
  puts "⚠️  Some operations failed. Please review."
  exit 1
else
  puts "✅ Phase 7 complete!"
  puts
  puts "Next steps:"
  puts "  1. Review changes: git diff openapi/mx_platform_api.yml"
  puts "  2. Verify types match models.yaml"
  puts "  3. Test preview server: http://127.0.0.1:8080"
  puts "  4. Commit changes"
end
