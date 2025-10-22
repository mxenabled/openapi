#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'json'
require 'pathname'
require 'set'
require 'date'
require 'time'

# OpenAPI Specification Comparison Tool
class OpenAPIComparator
  def initialize
    @base_path = Pathname.new(__dir__).parent / 'openapi'
    @differences = {
      'missing_schemas' => [],
      'missing_fields_in_schemas' => {},
      'missing_parameters' => [],
      'missing_paths' => [],
      'field_type_mismatches' => [],
      'missing_examples' => [],
      'nullable_mismatches' => [],
      'extra_schemas_in_mx' => [],
      'extra_fields_in_schemas' => {},
      'extra_parameters_in_mx' => [],
      'extra_paths_in_mx' => []
    }
  end

  def load_yaml(filename)
    filepath = @base_path / filename
    puts "Loading #{filepath}..."
    YAML.load_file(filepath, permitted_classes: [Date, Time, Symbol]) || {}
  rescue StandardError => e
    puts "Error loading #{filepath}: #{e.message}"
    {}
  end

  def get_all_schemas_from_docs_v2
    load_yaml('models.yaml')
  end

  def get_all_parameters_from_docs_v2
    load_yaml('parameters.yaml')
  end

  def get_paths_from_docs_v2
    v2_spec = load_yaml('v20111101.yaml')
    v2_spec['paths'] || {}
  end

  def get_schemas_from_mx_platform
    mx_spec = load_yaml('mx_platform_api.yml')
    mx_spec.dig('components', 'schemas') || {}
  end

  def get_paths_from_mx_platform
    mx_spec = load_yaml('mx_platform_api.yml')
    mx_spec['paths'] || {}
  end

  def compare_schemas
    puts "\n=== Comparing Schemas ==="

    docs_schemas = get_all_schemas_from_docs_v2
    mx_schemas = get_schemas_from_mx_platform

    docs_schema_names = Set.new(docs_schemas.keys)
    mx_schema_names = Set.new(mx_schemas.keys)

    # Find schemas in docs-v2 but missing in mx_platform_api
    missing_schemas = docs_schema_names - mx_schema_names
    missing_schemas.each do |schema_name|
      schema_def = docs_schemas[schema_name]
      fields = schema_def.is_a?(Hash) && schema_def['properties'] ? schema_def['properties'].keys : []
      @differences['missing_schemas'] << {
        'name' => schema_name,
        'source' => 'models.yaml',
        'fields' => fields
      }
    end

    # Find schemas in mx_platform_api but NOT in docs-v2 (should be removed)
    extra_schemas = mx_schema_names - docs_schema_names
    extra_schemas.each do |schema_name|
      schema_def = mx_schemas[schema_name]
      fields = schema_def.is_a?(Hash) && schema_def['properties'] ? schema_def['properties'].keys : []
      @differences['extra_schemas_in_mx'] << {
        'name' => schema_name,
        'fields' => fields
      }
    end

    # For schemas that exist in both, compare fields
    common_schemas = docs_schema_names & mx_schema_names
    common_schemas.each do |schema_name|
      compare_schema_fields(schema_name, docs_schemas[schema_name], mx_schemas[schema_name])
    end

    puts "  Missing schemas: #{missing_schemas.size}"
    puts "  Extra schemas (should remove): #{extra_schemas.size}"
    puts "  Common schemas: #{common_schemas.size}"
  end

  def compare_schema_fields(schema_name, docs_schema, mx_schema)
    return unless docs_schema.is_a?(Hash) && mx_schema.is_a?(Hash)

    docs_props = docs_schema['properties'] || {}
    mx_props = mx_schema['properties'] || {}

    docs_fields = Set.new(docs_props.keys)
    mx_fields = Set.new(mx_props.keys)

    # Fields in docs-v2 but missing in mx_platform_api
    missing_fields = docs_fields - mx_fields
    @differences['missing_fields_in_schemas'][schema_name] ||= []
    
    missing_fields.each do |field|
      field_def = docs_props[field]
      next unless field_def.is_a?(Hash)

      @differences['missing_fields_in_schemas'][schema_name] << {
        'field' => field,
        'type' => field_def['type'] || 'unknown',
        'example' => field_def['example'],
        'nullable' => field_def['nullable'],
        'description' => field_def['description']
      }
    end

    # Fields in mx_platform_api but NOT in docs-v2 (should be removed)
    extra_fields = mx_fields - docs_fields
    if extra_fields.any?
      @differences['extra_fields_in_schemas'][schema_name] ||= []
      
      extra_fields.each do |field|
        field_def = mx_props[field]
        next unless field_def.is_a?(Hash)

        @differences['extra_fields_in_schemas'][schema_name] << {
          'field' => field,
          'type' => field_def['type'] || 'unknown',
          'example' => field_def['example']
        }
      end
    end

    # For common fields, check for differences
    common_fields = docs_fields & mx_fields
    common_fields.each do |field|
      docs_field = docs_props[field]
      mx_field = mx_props[field]

      next unless docs_field.is_a?(Hash) && mx_field.is_a?(Hash)

      # Check type mismatches
      docs_type = docs_field['type']
      mx_type = mx_field['type']
      if docs_type && mx_type && docs_type != mx_type
        @differences['field_type_mismatches'] << {
          'schema' => schema_name,
          'field' => field,
          'docs_v2_type' => docs_type,
          'mx_platform_type' => mx_type
        }
      end

      # Check nullable mismatches
      docs_nullable = docs_field['nullable']
      mx_nullable = mx_field['nullable']
      if !docs_nullable.nil? && !mx_nullable.nil? && docs_nullable != mx_nullable
        @differences['nullable_mismatches'] << {
          'schema' => schema_name,
          'field' => field,
          'docs_v2_nullable' => docs_nullable,
          'mx_platform_nullable' => mx_nullable
        }
      end

      # Check missing examples
      if docs_field['example'] && !mx_field['example']
        @differences['missing_examples'] << {
          'schema' => schema_name,
          'field' => field,
          'docs_v2_example' => docs_field['example']
        }
      end
    end
  end

  def compare_parameters
    puts "\n=== Comparing Parameters ==="

    docs_params = get_all_parameters_from_docs_v2
    mx_spec = load_yaml('mx_platform_api.yml')
    mx_params = mx_spec.dig('components', 'parameters') || {}

    docs_param_names = Set.new(docs_params.keys)
    mx_param_names = Set.new(mx_params.keys)

    # Parameters in docs-v2 but missing in mx_platform_api
    missing_params = docs_param_names - mx_param_names
    missing_params.each do |param_name|
      param_def = docs_params[param_name]
      next unless param_def.is_a?(Hash)

      @differences['missing_parameters'] << {
        'name' => param_name,
        'in' => param_def['in'] || 'unknown',
        'required' => param_def['required'],
        'description' => param_def['description']
      }
    end

    # Parameters in mx_platform_api but NOT in docs-v2 (should be removed)
    extra_params = mx_param_names - docs_param_names
    extra_params.each do |param_name|
      param_def = mx_params[param_name]
      next unless param_def.is_a?(Hash)

      @differences['extra_parameters_in_mx'] << {
        'name' => param_name,
        'in' => param_def['in'] || 'unknown',
        'required' => param_def['required']
      }
    end

    puts "  Missing parameters: #{missing_params.size}"
    puts "  Extra parameters (should remove): #{extra_params.size}"
  end

  def compare_paths
    puts "\n=== Comparing Paths ==="

    docs_paths = get_paths_from_docs_v2
    mx_paths = get_paths_from_mx_platform

    docs_path_names = Set.new(docs_paths.keys)
    mx_path_names = Set.new(mx_paths.keys)

    # Paths in docs-v2 but missing in mx_platform_api
    missing_paths = docs_path_names - mx_path_names
    missing_paths.each do |path|
      path_def = docs_paths[path]
      methods = path_def.is_a?(Hash) ? path_def.keys : []
      @differences['missing_paths'] << {
        'path' => path,
        'methods' => methods
      }
    end

    # Paths in mx_platform_api but NOT in docs-v2 (should be removed)
    extra_paths = mx_path_names - docs_path_names
    extra_paths.each do |path|
      path_def = mx_paths[path]
      methods = path_def.is_a?(Hash) ? path_def.keys : []
      @differences['extra_paths_in_mx'] << {
        'path' => path,
        'methods' => methods
      }
    end

    puts "  Missing paths: #{missing_paths.size}"
    puts "  Extra paths (should remove): #{extra_paths.size}"
    puts "  Common paths: #{(docs_path_names & mx_path_names).size}"
  end

  def generate_report
    report = []
    report << '# OpenAPI Specification Comparison Report'
    report << "\nGenerated: #{Time.now}"
    report << "\n## Executive Summary\n"

    total_issues = @differences['missing_schemas'].size +
                   @differences['missing_fields_in_schemas'].values.sum(&:size) +
                   @differences['missing_parameters'].size +
                   @differences['missing_paths'].size +
                   @differences['field_type_mismatches'].size +
                   @differences['nullable_mismatches'].size +
                   @differences['extra_schemas_in_mx'].size +
                   @differences['extra_fields_in_schemas'].values.sum(&:size) +
                   @differences['extra_parameters_in_mx'].size +
                   @differences['extra_paths_in_mx'].size

    report << "**Total Differences Found:** #{total_issues}\n"
    report << "- Missing Schemas: #{@differences['missing_schemas'].size}"
    report << "- Schemas with Missing Fields: #{@differences['missing_fields_in_schemas'].size}"
    report << "- Missing Parameters: #{@differences['missing_parameters'].size}"
    report << "- Missing Paths: #{@differences['missing_paths'].size}"
    report << "- Field Type Mismatches: #{@differences['field_type_mismatches'].size}"
    report << "- Nullable Mismatches: #{@differences['nullable_mismatches'].size}"
    report << "- **Extra Schemas in mx_platform_api (REMOVE):** #{@differences['extra_schemas_in_mx'].size}"
    report << "- **Extra Fields in Schemas (REMOVE):** #{@differences['extra_fields_in_schemas'].size}"
    report << "- **Extra Parameters in mx_platform_api (REMOVE):** #{@differences['extra_parameters_in_mx'].size}"
    report << "- **Extra Paths in mx_platform_api (REMOVE):** #{@differences['extra_paths_in_mx'].size}"

    # Missing Schemas
    unless @differences['missing_schemas'].empty?
      report << "\n## Missing Schemas\n"
      report << "These schemas exist in `models.yaml` but are missing from `mx_platform_api.yml`:\n"
      @differences['missing_schemas'].sort_by { |s| s['name'] }.each do |schema|
        report << "### #{schema['name']}"
        report << "- **Source:** #{schema['source']}"
        if schema['fields']&.any?
          fields_preview = schema['fields'].take(10)
          report << "- **Fields:** #{fields_preview.join(', ')}"
          report << "  ... and #{schema['fields'].size - 10} more" if schema['fields'].size > 10
        end
        report << ''
      end
    end

    # Extra Schemas (should be removed)
    unless @differences['extra_schemas_in_mx'].empty?
      report << "\n## ⚠️ Extra Schemas in mx_platform_api.yml (SHOULD BE REMOVED)\n"
      report << "These schemas exist in `mx_platform_api.yml` but NOT in `models.yaml`:\n"
      report << "**Action Required:** Remove these schemas for total parity with docs-v2.\n"
      @differences['extra_schemas_in_mx'].sort_by { |s| s['name'] }.each do |schema|
        report << "### #{schema['name']}"
        if schema['fields']&.any?
          fields_preview = schema['fields'].take(10)
          report << "- **Fields:** #{fields_preview.join(', ')}"
          report << "  ... and #{schema['fields'].size - 10} more" if schema['fields'].size > 10
        end
        report << ''
      end
    end

    # Missing Fields in Schemas
    unless @differences['missing_fields_in_schemas'].empty?
      report << "\n## Missing Fields in Existing Schemas\n"
      report << "These schemas exist in both files, but are missing fields from docs-v2:\n"
      @differences['missing_fields_in_schemas'].keys.sort.each do |schema_name|
        fields = @differences['missing_fields_in_schemas'][schema_name]
        report << "### #{schema_name} (#{fields.size} missing fields)\n"
        fields.each do |field_info|
          report << "- **#{field_info['field']}**"
          report << "  - Type: `#{field_info['type']}`"
          report << "  - Example: `#{field_info['example']}`" if field_info['example']
          report << "  - Nullable: `#{field_info['nullable']}`" if field_info['nullable']
          if field_info['description']
            desc = field_info['description'][0..100]
            report << "  - Description: #{desc}..."
          end
        end
        report << ''
      end
    end

    # Extra Fields in Schemas (should be removed)
    unless @differences['extra_fields_in_schemas'].empty?
      report << "\n## ⚠️ Extra Fields in Schemas (SHOULD BE REMOVED)\n"
      report << "These fields exist in `mx_platform_api.yml` but NOT in `models.yaml`:\n"
      report << "**Action Required:** Remove these fields for total parity with docs-v2.\n"
      @differences['extra_fields_in_schemas'].keys.sort.each do |schema_name|
        fields = @differences['extra_fields_in_schemas'][schema_name]
        report << "### #{schema_name} (#{fields.size} extra fields)\n"
        fields.each do |field_info|
          report << "- **#{field_info['field']}**"
          report << "  - Type: `#{field_info['type']}`"
          report << "  - Example: `#{field_info['example']}`" if field_info['example']
        end
        report << ''
      end
    end

    # Field Type Mismatches
    unless @differences['field_type_mismatches'].empty?
      report << "\n## Field Type Mismatches\n"
      report << "These fields exist in both but have different types:\n"
      @differences['field_type_mismatches'].each do |mismatch|
        report << "- **#{mismatch['schema']}.#{mismatch['field']}**"
        report << "  - docs-v2: `#{mismatch['docs_v2_type']}`"
        report << "  - mx_platform_api: `#{mismatch['mx_platform_type']}`"
      end
      report << ''
    end

    # Nullable Mismatches
    unless @differences['nullable_mismatches'].empty?
      report << "\n## Nullable Flag Mismatches\n"
      report << "These fields have different nullable settings:\n"
      @differences['nullable_mismatches'].each do |mismatch|
        report << "- **#{mismatch['schema']}.#{mismatch['field']}**"
        report << "  - docs-v2: `#{mismatch['docs_v2_nullable']}`"
        report << "  - mx_platform_api: `#{mismatch['mx_platform_nullable']}`"
      end
      report << ''
    end

    # Missing Parameters
    unless @differences['missing_parameters'].empty?
      report << "\n## Missing Parameters\n"
      report << "These parameters exist in `parameters.yaml` but are missing from `mx_platform_api.yml`:\n"
      @differences['missing_parameters'].sort_by { |p| p['name'] }.each do |param|
        report << "### #{param['name']}"
        report << "- **Location:** #{param['in']}"
        report << "- **Required:** #{param['required']}"
        if param['description']
          desc = param['description'][0..150]
          report << "- **Description:** #{desc}..."
        end
        report << ''
      end
    end

    # Extra Parameters (should be removed)
    unless @differences['extra_parameters_in_mx'].empty?
      report << "\n## ⚠️ Extra Parameters in mx_platform_api.yml (SHOULD BE REMOVED)\n"
      report << "These parameters exist in `mx_platform_api.yml` but NOT in `parameters.yaml`:\n"
      report << "**Action Required:** Remove these parameters for total parity with docs-v2.\n"
      @differences['extra_parameters_in_mx'].sort_by { |p| p['name'] }.each do |param|
        report << "### #{param['name']}"
        report << "- **Location:** #{param['in']}"
        report << "- **Required:** #{param['required']}"
        report << ''
      end
    end

    # Missing Paths
    unless @differences['missing_paths'].empty?
      report << "\n## Missing Paths/Endpoints\n"
      report << "These paths exist in `v20111101.yaml` but are missing from `mx_platform_api.yml`:\n"
      @differences['missing_paths'].sort_by { |p| p['path'] }.each do |path|
        report << "- `#{path['path']}`"
        report << "  - Methods: #{path['methods'].join(', ')}"
      end
      report << ''
    end

    # Extra Paths (should be removed)
    unless @differences['extra_paths_in_mx'].empty?
      report << "\n## ⚠️ Extra Paths in mx_platform_api.yml (SHOULD BE REMOVED)\n"
      report << "These paths exist in `mx_platform_api.yml` but NOT in `v20111101.yaml`:\n"
      report << "**Action Required:** Remove these paths for total parity with docs-v2.\n"
      @differences['extra_paths_in_mx'].sort_by { |p| p['path'] }.each do |path|
        report << "- `#{path['path']}`"
        report << "  - Methods: #{path['methods'].join(', ')}"
      end
      report << ''
    end

    # Recommendations
    report << "\n## Recommendations\n"
    report << "### Priority 1: Remove Extra Content (Breaking Changes)"
    report << "- **CRITICAL:** Remove extra schemas, fields, parameters, and paths"
    report << "- These don't exist in docs-v2 and break parity"
    report << "- Coordinate with SDK team before removing (potential breaking changes)"
    report << ''
    report << "### Priority 2: Critical Schema Updates"
    report << "- Add missing fields to existing schemas (affects API responses)"
    report << "- Fix type mismatches to match docs-v2 spec"
    report << "- Update nullable flags for consistency"
    report << ''
    report << "### Priority 2: New Schemas"
    report << "- Add completely missing schemas from models.yaml"
    report << ''
    report << "### Priority 3: Parameters & Paths"
    report << "- Add missing parameters from parameters.yaml"
    report << "- Add missing endpoint paths from v20111101.yaml"
    report << ''
    report << "### Priority 4: Enhancement"
    report << "- Add missing examples to fields that have them in docs-v2"
    report << ''
    report << "## Next Steps\n"
    report << "1. Review this report and prioritize which differences to address"
    report << "2. Create incremental changes (max 1-2 schemas per commit)"
    report << "3. Run `bundle exec rake normalize` after each change"
    report << "4. Run `bundle exec rake validate` before committing"
    report << "5. Test with SDK generation to verify no breaking changes"

    report.join("\n")
  end

  def run
    puts "\n" + ('=' * 60)
    puts 'OpenAPI Specification Comparison Tool'
    puts '=' * 60

    compare_schemas
    compare_parameters
    compare_paths

    # Generate reports
    puts "\n=== Generating Reports ==="

    # Markdown report
    report_path = Pathname.new(__dir__) / 'comparison_report.md'
    File.write(report_path, generate_report)
    puts "  Markdown report: #{report_path}"

    # JSON diff
    json_path = Pathname.new(__dir__) / 'comparison_diff.json'
    File.write(json_path, JSON.pretty_generate(@differences))
    puts "  JSON diff: #{json_path}"

    puts "\n" + ('=' * 60)
    puts 'Comparison Complete!'
    puts '=' * 60
    puts "\nReview the detailed report at: #{report_path}"
  end
end

# Run the comparator
comparator = OpenAPIComparator.new
comparator.run
