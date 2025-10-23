#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

# Script to synchronize OpenAPI path tags from v20111101.yaml to mx_platform_api.yml
# Uses yq for format-preserving YAML manipulation

SOURCE_FILE = 'openapi/v20111101.yaml'
TARGET_FILE = 'openapi/mx_platform_api.yml'

def check_yq
  version_output = `yq --version 2>&1`
  unless $?.success?
    puts "❌ ERROR: yq is not installed"
    puts "Please install: brew install yq"
    exit 1
  end
  puts "✓ Using #{version_output.strip}"
end

def run_command(cmd)
  output = `#{cmd} 2>&1`
  success = $?.success?
  [success, output.strip]
end

def get_path_tags(filepath)
  # Get all paths with their methods and tags
  tag_map = {}
  
  # First, get all paths
  cmd = "yq eval '.paths | keys' -o json #{filepath}"
  success, output = run_command(cmd)
  
  unless success
    puts "❌ Failed to extract paths from #{filepath}"
    puts output
    exit 1
  end
  
  paths = JSON.parse(output)
  
  paths.each do |path|
    # Get methods for this path
    escaped_path = path.gsub("'", "'\\''")
    cmd = "yq eval '.paths[\"#{escaped_path}\"] | keys' -o json #{filepath}"
    success, output = run_command(cmd)
    next unless success
    
    methods = JSON.parse(output)
    
    methods.each do |method|
      # Skip if not an HTTP method
      next unless %w[get post put patch delete].include?(method)
      
      # Get tags for this method
      cmd = "yq eval '.paths[\"#{escaped_path}\"].#{method}.tags' -o json #{filepath}"
      success, output = run_command(cmd)
      next unless success
      
      tags = JSON.parse(output)
      next if tags.nil? || tags.empty?
      
      key = "#{path}::#{method}"
      tag_map[key] = tags.first.strip # Use first tag, strip whitespace
    end
  end
  
  tag_map
end

def extract_tag_map(tag_map)
  # Already in the right format from get_path_tags
  tag_map
end

def update_tag(filepath, path, method, new_tag)
  # Use yq to update the tag for a specific path and method
  # Escape single quotes in path for shell safety
  escaped_path = path.gsub("'", "'\\''")
  
  cmd = "yq eval '.paths[\"#{escaped_path}\"].#{method}.tags = [\"#{new_tag}\"]' -i #{filepath}"
  success, output = run_command(cmd)
  
  unless success
    puts "❌ Failed to update tag for #{method.upcase} #{path}"
    puts output
    return false
  end
  
  true
end

# Main execution
puts "=" * 80
puts "OpenAPI Tag Synchronization"
puts "=" * 80
puts

check_yq

puts "📖 Reading tags from source: #{SOURCE_FILE}"
source_tags = get_path_tags(SOURCE_FILE)
puts "   Found #{source_tags.size} path operations with tags"
puts

puts "📖 Reading tags from target: #{TARGET_FILE}"
target_tags = get_path_tags(TARGET_FILE)
puts "   Found #{target_tags.size} path operations with tags"
puts

# Find tags that need updating
updates_needed = []

target_tags.each do |key, current_tag|
  path, method = key.split('::', 2)
  source_tag = source_tags[key]
  
  if source_tag && source_tag != current_tag
    updates_needed << {
      path: path,
      method: method,
      current_tag: current_tag,
      new_tag: source_tag
    }
  end
end

if updates_needed.empty?
  puts "✅ All tags already synchronized!"
  exit 0
end

puts "🔍 Found #{updates_needed.size} tags to update:"
puts

# Group by current tag to show impact
by_current_tag = updates_needed.group_by { |u| u[:current_tag] }
by_current_tag.each do |tag, updates|
  puts "   From '#{tag}': #{updates.size} operations"
end
puts

# Group by new tag to show distribution
by_new_tag = updates_needed.group_by { |u| u[:new_tag] }
by_new_tag.each do |tag, updates|
  puts "   To '#{tag}': #{updates.size} operations"
end
puts

puts "📝 Updating tags in #{TARGET_FILE}..."
puts

success_count = 0
error_count = 0

updates_needed.each_with_index do |update, index|
  path = update[:path]
  method = update[:method]
  current_tag = update[:current_tag]
  new_tag = update[:new_tag]
  
  print "   [#{index + 1}/#{updates_needed.size}] #{method.upcase} #{path}"
  print "\n      '#{current_tag}' → '#{new_tag}' ... "
  
  if update_tag(TARGET_FILE, path, method, new_tag)
    puts "✓"
    success_count += 1
  else
    puts "✗"
    error_count += 1
  end
end

puts
puts "=" * 80
puts "Summary:"
puts "  ✓ Updated: #{success_count}"
puts "  ✗ Failed:  #{error_count}" if error_count > 0
puts "=" * 80
puts

if error_count > 0
  puts "⚠️  Some updates failed. Please review the errors above."
  exit 1
else
  puts "✅ Tag synchronization complete!"
  puts
  puts "Next steps:"
  puts "  1. Review changes: git diff openapi/mx_platform_api.yml"
  puts "  2. Verify preview server: http://127.0.0.1:8080"
  puts "  3. Commit changes: git add + git commit"
end
