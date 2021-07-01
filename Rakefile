# frozen_string_literal: true

require 'openapi3_parser'
require 'rubocop/rake_task'
require 'yaml_normalizer'

::RuboCop::RakeTask.new(:rubocop)

OPENAPI_YML_FILES = ::Dir.glob('openapi/*.yml')

def print_validation_errors(file, openapi)
  errors_count = openapi.errors.count

  puts "#{errors_count} validation error(s) found in #{file}"
  openapi.errors.each_with_index do |error, index|
    context = error.context.source_location.pointer.fragment
    current_index = index + 1
    error_message = error.message
    unescaped_context = ::CGI.unescape(context)

    puts "\n#{current_index})\n  Message: #{error_message}\n  Context: #{unescaped_context}"
  end
  exit 1
end

def validate_openapi(file)
  openapi = ::Openapi3Parser.load_file(file)

  print_validation_errors(file, openapi) unless openapi.valid?
  puts "[PASSED] #{file} is valid OpenAPI"
end

def yaml_normalizer_check(file)
  check_passed = ::YamlNormalizer::Services::Check.call(file)

  return if check_passed

  puts "Please normalize /openapi/*.yml files with 'bundle exec rake normalize'"
  exit 1
end

task default: %i[rubocop validate]

task :normalize do
  OPENAPI_YML_FILES.each do |file|
    ::YamlNormalizer::Services::Normalize.call(file)
  end
end

task :validate do
  OPENAPI_YML_FILES.each do |file|
    puts "\nValidating #{file}"
    validate_openapi(file)
    yaml_normalizer_check(file)
  end
end
