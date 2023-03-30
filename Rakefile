# frozen_string_literal: true

require 'rubocop/rake_task'
require 'yaml_normalizer'

::RuboCop::RakeTask.new(:rubocop)

OPENAPI_YML_FILES = ::Dir.glob('openapi/*.yml')

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
    yaml_normalizer_check(file)
  end
end
