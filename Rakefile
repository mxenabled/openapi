require "openapi3_parser"
require "yaml_normalizer"

task :default => [:validate_openapi, :normalize_yaml]

task :normalize do
  ::YamlNormalizer::Services::Normalize.call("openapi.yml")
end

task :normalize_yaml do
  check_passed = ::YamlNormalizer::Services::Check.call("openapi.yml")

  unless check_passed
    puts "Please normalize openapi.yml with 'bundle exec rake normalize'"
    exit 1
  end
end

task :validate_openapi do
  openapi = ::Openapi3Parser.load_file("openapi.yml")

  unless openapi.valid?
    errors_count = openapi.errors.count

    puts "#{errors_count} validation error(s) found."
    openapi.errors.each_with_index do |error, index|
      context = error.context.source_location.pointer.fragment
      error_message = error.message
      unescaped_context = ::CGI.unescape(context)

      puts ""
      puts "#{index + 1})"
      puts "   Message: #{error_message}"
      puts "   Context: #{unescaped_context}"
    end
    exit 1
  end

  puts "[PASSED] valid OpenAPI"
end
