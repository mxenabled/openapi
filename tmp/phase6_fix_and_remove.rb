#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 6: Fix schema structures and remove deprecated schemas
# - Update schemas to match models.yaml structure (using Elements)
# - Remove deprecated schemas that don't exist in models.yaml

TARGET_FILE = 'openapi/mx_platform_api.yml'

def run_command(cmd)
  output = `#{cmd} 2>&1`
  success = $?.success?
  [success, output.strip]
end

puts "=" * 80
puts "Phase 6: Fix Schema Structures and Remove Deprecated Schemas"
puts "=" * 80
puts

# Step 1: Update RewardResponseBody to use RewardElements
puts "Step 1: Updating RewardResponseBody..."
cmd = <<~YQ
  yq eval '
    .components.schemas.RewardResponseBody.properties.reward = {
      "allOf": [
        {"$ref": "#/components/schemas/MemberElements"},
        {"$ref": "#/components/schemas/RewardElements"}
      ]
    }
  ' -i #{TARGET_FILE}
YQ

success, output = run_command(cmd)
if success
  puts "   ✓ RewardResponseBody updated"
else
  puts "   ✗ Failed: #{output}"
  exit 1
end

# Step 2: Update RewardsResponseBody to use RewardElements
puts "Step 2: Updating RewardsResponseBody..."
cmd = <<~YQ
  yq eval '
    .components.schemas.RewardsResponseBody.properties.rewards.items = {
      "allOf": [
        {"$ref": "#/components/schemas/MemberElements"},
        {"$ref": "#/components/schemas/RewardElements"}
      ]
    }
  ' -i #{TARGET_FILE}
YQ

success, output = run_command(cmd)
if success
  puts "   ✓ RewardsResponseBody updated"
else
  puts "   ✗ Failed: #{output}"
  exit 1
end

# Step 3: Update MicrodepositRequestBody to use MicrodepositElements
puts "Step 3: Updating MicrodepositRequestBody..."
cmd = <<~YQ
  yq eval '
    .components.schemas.MicrodepositRequestBody.properties.micro_deposit = {
      "$ref": "#/components/schemas/MicrodepositElements"
    }
  ' -i #{TARGET_FILE}
YQ

success, output = run_command(cmd)
if success
  puts "   ✓ MicrodepositRequestBody updated"
else
  puts "   ✗ Failed: #{output}"
  exit 1
end

puts
puts "Step 4: Removing deprecated schemas..."

# Now remove the deprecated schemas that are no longer referenced
deprecated_schemas = [
  'RewardResponse',
  'RewardsResponse',
  'MicrodepositRequest',
  'HoldingResponse',
  'HoldingResponseBody',
  'HoldingsResponseBody',
  'TaxDocumentResponse',
  'TaxDocumentResponseBody',
  'TaxDocumentsResponseBody'
]

deprecated_schemas.each do |schema|
  print "   Removing #{schema}... "
  cmd = "yq eval 'del(.components.schemas.\"#{schema}\")' -i #{TARGET_FILE}"
  success, output = run_command(cmd)
  
  if success
    puts "✓"
  else
    puts "✗ (#{output})"
  end
end

puts
puts "=" * 80
puts "Phase 6 Complete!"
puts "=" * 80
puts
puts "Next steps:"
puts "  1. Review changes: git diff openapi/mx_platform_api.yml"
puts "  2. Verify no broken references"
puts "  3. Test preview server: http://127.0.0.1:8080"
puts "  4. Run comparison: ruby tmp/compare_openapi_specs.rb"
