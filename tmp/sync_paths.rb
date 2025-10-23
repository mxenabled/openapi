#!/usr/bin/env ruby
# frozen_string_literal: true
#
# See tmp/TECHNOLOGY_STACK.md for Ruby-only requirements
# Uses yq to preserve YAML formatting (no reformatting side effects)

require 'json'
require 'tempfile'

# PHASE 4: Sync Paths between v20111101.yaml and mx_platform_api.yml
#
# USAGE:
#   ruby tmp/sync_paths.rb
#
# NOTES:
#   - Phase 4a: Adds missing paths from v20111101.yaml
#   - Phase 4b: Removes extra paths from mx_platform_api.yml (BREAKING)
#   - Uses yq to preserve exact YAML formatting
#   - No quote changes, no whitespace changes, no date format changes

# Configuration
V2_FILE = 'openapi/v20111101.yaml'
MX_FILE = 'openapi/mx_platform_api.yml'

def run_command(cmd)
  output = `#{cmd} 2>&1`
  success = $?.success?
  [success, output.strip]
end

def check_yq
  success, version = run_command("yq --version")
  unless success
    puts "ERROR: yq is not installed. Install with: brew install yq"
    exit 1
  end
  version
end

def get_paths_list(filepath)
  success, output = run_command("yq '.paths | keys' -o json #{filepath}")
  unless success
    puts "Error getting paths from #{filepath}: #{output}"
    exit 1
  end
  JSON.parse(output)
rescue StandardError => e
  puts "Error parsing paths from #{filepath}: #{e.message}"
  exit 1
end

def main
  puts "=" * 80
  puts "PHASE 4: PATH SYNCHRONIZATION (using yq)"
  puts "=" * 80
  puts

  # Check yq is available
  yq_version = check_yq
  puts "Using #{yq_version}"
  puts

  # Get paths from both files
  puts "Analyzing paths..."
  v2_paths = get_paths_list(V2_FILE).sort
  mx_paths = get_paths_list(MX_FILE).sort

  puts "v20111101.yaml paths: #{v2_paths.size}"
  puts "mx_platform_api.yml paths: #{mx_paths.size}"
  puts

  # Part 1: Find missing paths (in v2 but not in mx)
  missing_paths = (v2_paths - mx_paths).sort
  
  # Part 2: Find extra paths (in mx but not in v2)
  extra_paths = (mx_paths - v2_paths).sort

  puts "=" * 80
  puts "PART 1: ADD MISSING PATHS"
  puts "=" * 80
  puts "Paths to add: #{missing_paths.size}"
  
  if missing_paths.empty?
    puts "✓ No missing paths to add"
  else
    # For each missing path, copy from v2 to mx using yq
    missing_paths.each do |path|
      puts "  + #{path}"
      
      # Use yq to copy path definition preserving format
      # Get the path from v2 file and merge into mx file
      cmd = "yq eval-all 'select(fileIndex == 0).paths.\"#{path}\" as $path | select(fileIndex == 1) | .paths.\"#{path}\" = $path' #{V2_FILE} #{MX_FILE} > #{MX_FILE}.tmp && mv #{MX_FILE}.tmp #{MX_FILE}"
      
      success, output = run_command(cmd)
      if success
        puts "    ✓ Added"
      else
        puts "    ✗ Failed: #{output}"
        exit 1
      end
    end
  end
  puts

  puts "=" * 80
  puts "PART 2: REMOVE EXTRA PATHS (BREAKING)"
  puts "=" * 80
  puts "Paths to remove: #{extra_paths.size}"
  
  if extra_paths.empty?
    puts "✓ No extra paths to remove"
  else
    extra_paths.each do |path|
      puts "  - #{path}"
      
      # Use yq to delete the path
      cmd = "yq 'del(.paths.\"#{path}\")' #{MX_FILE} > #{MX_FILE}.tmp && mv #{MX_FILE}.tmp #{MX_FILE}"
      
      success, output = run_command(cmd)
      if success
        puts "    ✓ Removed"
      else
        puts "    ✗ Failed: #{output}"
        exit 1
      end
    end
  end
  puts

  # Get final count
  final_paths = get_paths_list(MX_FILE)

  puts "=" * 80
  puts "SUMMARY"
  puts "=" * 80
  puts "✓ Added #{missing_paths.size} missing paths"
  puts "✓ Removed #{extra_paths.size} extra paths"
  puts "✓ Total paths now: #{final_paths.size}"
  puts "✓ Formatting preserved (no reformatting side effects)"
  puts
  puts "Phase 4 complete!"
end

main if __FILE__ == $PROGRAM_NAME
