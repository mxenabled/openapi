# frozen_string_literal: true

source 'https://rubygems.org'

gem 'openapi3_parser'
gem 'rake'
gem 'rubocop'

# TODO: The `openapi3_parser` and `yaml_normalizer` gems have a compatibility issue
#       as both have pinned the `psych` dependency to different versions. We are
#       currently using a forked version of the `yaml_normalizer` gem which has the
#       `pysch` gem unpinned. Once the gems are compatible we can remove this git source.
#       PR: https://github.com/Sage/yaml_normalizer/pull/53
gem 'yaml_normalizer', git: 'https://github.com/mxenabled/yaml_normalizer'
