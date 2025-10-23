# Technology Stack

## CRITICAL: Ruby Only

**ALL scripts in this project MUST use Ruby.**

- ✅ **Ruby** - Primary and ONLY scripting language
- ❌ **Python** - DO NOT USE
- ❌ **Node.js** - DO NOT USE
- ❌ **Shell scripts** - Minimize use, prefer Ruby

## Why Ruby Only?

1. **Consistency** - Single language for all automation
2. **Team Expertise** - Ruby is the team's primary language
3. **Dependency Management** - Bundler for all dependencies
4. **No Mixed Dependencies** - Avoid pip, npm, etc.

## Allowed Dependencies

### Ruby Standard Library
- `yaml` - YAML parsing (with caveats - see below)
- `json` - JSON parsing
- `date` - Date/time handling
- `fileutils` - File operations
- `set` - Set data structures

### External Tools (Use with Caution)
- `git` - Version control commands
- `grep` - Text search (when grep_search tools not available)
- `sed` - Text replacement (when necessary)

## YAML Handling - CRITICAL RULES

### Problem: YAML Reformatting

Ruby's YAML library (`Psych`) **reformats the entire file** when you do:
```ruby
data = YAML.load_file('file.yml')
File.write('file.yml', YAML.dump(data))
```

**This causes:**
- Quote style changes: `"value"` → `value` or `'value'`
- Indentation changes
- Whitespace changes in multiline strings
- Date format changes: `"2023-01-01T00:00:00Z"` → `'2023-01-01T00:00:00Z'`
- Order changes in unordered collections
- **Result**: Massive diffs (2000+ line changes for simple edits)

### Solutions

#### Option 1: Text-Based Manipulation (PREFERRED for paths/small changes)
```ruby
# Read file as text
content = File.read('file.yml')

# Use regex or line-by-line editing
# Insert/remove sections without parsing
content.sub!(/old_pattern/, 'new_content')

# Write back
File.write('file.yml', content)
```

#### Option 2: External YAML Tools
```ruby
# Use yq (YAML processor) if available
`yq '.paths += {"new_path": {...}}' file.yml > temp.yml && mv temp.yml file.yml`
```

#### Option 3: Targeted Ruby YAML (use sparingly)
```ruby
# Only when you MUST parse/modify complex structures
# And accept the reformatting consequences
data = YAML.load_file('file.yml', permitted_classes: [Time, Date, Symbol])
# ... modify data ...
File.write('file.yml', YAML.dump(data))
```

## Script Requirements

Every script MUST:
1. ✅ Use Ruby (`#!/usr/bin/env ruby`)
2. ✅ Include frozen_string_literal comment
3. ✅ Handle errors gracefully
4. ✅ Print clear status messages
5. ✅ Preserve file formatting when possible
6. ✅ Document YAML reformatting if unavoidable

## Examples

### ✅ CORRECT - Text-based path insertion
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

content = File.read('openapi/mx_platform_api.yml')

# Find insertion point
insertion_point = content.index(/^  "\/users"/)

# Insert new path before it
new_path = %{  "/ach_returns":\n    get:\n      summary: List ACH returns\n}
content.insert(insertion_point, new_path)

File.write('openapi/mx_platform_api.yml', content)
```

### ❌ WRONG - Full YAML reload (causes reformatting)
```ruby
#!/usr/bin/env ruby

require 'yaml'

# This reformats the ENTIRE file!
data = YAML.load_file('openapi/mx_platform_api.yml')
data['paths']['/new_path'] = {...}
File.write('openapi/mx_platform_api.yml', YAML.dump(data))
```

## Current Phase 4 Solution

The `sync_paths.rb` script now uses `yq` (YAML processor) which preserves formatting:
- Changed 1,791 lines total
- 900 insertions, 891 deletions (mostly path additions/removals + whitespace cleanup)
- No quote style changes, no date format changes
- Only minimal formatting improvements (trailing space removal, array formatting)

**Tool Used**: `yq` v4.48.1 (installed via `brew install yq`)

## Removed Files

The following non-Ruby files have been removed to enforce Ruby-only policy:
- `tmp/compare_openapi_specs.py` - Python version (Ruby version exists at `tmp/compare_openapi_specs.rb`)

## Documentation Location

This file: `/Users/nicki.nixon/Documents/repos/openapi/tmp/TECHNOLOGY_STACK.md`

Reference in all script headers:
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
#
# See tmp/TECHNOLOGY_STACK.md for Ruby-only requirements
```

---

**Last Updated**: 2025-10-22  
**Enforce**: Ruby only, no Python, preserve YAML formatting
