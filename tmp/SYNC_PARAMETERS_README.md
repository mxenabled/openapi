# Parameter Synchronization Script

## Purpose

`sync_parameters.rb` synchronizes parameters between docs-v2 reference files (parameters.yaml) and the consolidated OpenAPI specification (mx_platform_api.yml), achieving **exact parity** by:

- ✅ **Adding** missing parameters from parameters.yaml to mx_platform_api.yml
- ❌ **Removing** extra parameters from mx_platform_api.yml not in parameters.yaml
- 🏗️ **Creating** `components.parameters` section if it doesn't exist
- 🔄 **Converting** inline parameter definitions to `$ref` (Phase 3b)

**This is an atomic operation**: Both library creation (Phase 3a) and inline conversion (Phase 3b) happen in a single run, ensuring the file is never left in an incomplete state.

## Expected Results

When run on a typical OpenAPI spec with ~72 parameters used in ~350 locations:

- **Phase 3a**: Adds 518 lines (components.parameters library)
- **Phase 3b**: Removes 2,345 lines (inline definitions replaced with $ref)
- **Net result**: -1,466 lines (~14% file size reduction)
- **Benefit**: Single source of truth, no duplication, easier maintenance

## Usage

### Default (Current Version)

```bash
ruby tmp/sync_parameters.rb
```

Uses default paths:
- Source: `openapi/parameters.yaml`
- Target: `openapi/mx_platform_api.yml`
- Diff: `tmp/comparison_diff.json`

### Future Versions (e.g., v20250224)

```bash
ruby tmp/sync_parameters.rb \
  openapi/parameters.yaml \
  openapi/mx_platform_api_v20250224.yml \
  tmp/comparison_diff_v20250224.json
```

## Prerequisites

1. **Run comparison script first** to generate `comparison_diff.json`:
   ```bash
   ruby tmp/compare_openapi_specs.rb
   ```

2. **Verify the diff** to understand what will change:
   ```bash
   cat tmp/comparison_report.md
   grep -A 2 "missing_parameters" tmp/comparison_diff.json
   ```

## How It Works

### Phase 1: Create Parameters Section (if needed)

If `components.parameters` doesn't exist, the script creates it:

1. **Preferred location**: Before `securitySchemes:` (within components)
   ```yaml
   components:
     schemas:
       # ... existing schemas
     parameters:  # ← Created here
       # ... parameters will be added
     securitySchemes:
       # ... existing security schemes
   ```

2. **Fallback location**: Before `paths:` (if no securitySchemes)
   ```yaml
   components:
     schemas:
       # ... existing schemas
     parameters:  # ← Created here
   paths:
     # ... paths
   ```

### Phase 2: Add Missing Parameters

For each parameter in `missing_parameters` from comparison:

1. **Extract from source** (parameters.yaml):
   ```yaml
   page:
     description: Specify current page.
     example: 1
     in: query
     name: page
     schema:
       type: integer
   ```

2. **Adjust indentation** (add 4 spaces to all lines):
   - Parameter name: 0-space → 4-space
   - Parameter content: 2-space → 6-space

3. **Convert $ref format** (if any):
   - External: `$ref: '#/ParamName'`
   - Internal: `$ref: '#/components/parameters/ParamName'`

4. **Insert** at the beginning of `components.parameters` section

### Phase 3: Remove Extra Parameters

For each parameter in `extra_parameters_in_mx` from comparison:

1. **Match pattern** in mx_platform_api.yml:
   ```yaml
       paramName:
         description: ...
         in: query
         ...
   ```

2. **Remove** entire parameter definition (including all nested content)

## Indentation Structure

**Critical**: Parameters must follow OpenAPI indentation standards:

```yaml
components:                    # 0-space (root)
  parameters:                  # 2-space (components child)
    page:                      # 4-space (parameter name)
      description: Current page # 6-space (parameter properties)
      in: query                # 6-space
      name: page               # 6-space
      schema:                  # 6-space
        type: integer          # 8-space (nested property)
```

**Source format** (parameters.yaml):
- Parameter name: 0-space
- Parameter content: 2-space

**Target format** (mx_platform_api.yml):
- Parameter name: 4-space (under `components.parameters`)
- Parameter content: 6-space

**Transformation**: Add 4 spaces to every line

## Example Execution

### Before Running Script

Check what will change:
```bash
$ ruby tmp/compare_openapi_specs.rb | grep -i parameter
  Missing parameters: 72
  Extra parameters (should remove): 0
```

### Run Script

```bash
$ ruby tmp/sync_parameters.rb

Reading comparison data from: tmp/comparison_diff.json
Loading parameters from: openapi/parameters.yaml
Loading API file: openapi/mx_platform_api.yml

Found:
  - 72 parameters to add
  - 0 parameters to remove

Adding 72 missing parameters...
  Creating parameters section...
  ✅ Created parameters section before securitySchemes
  ✅ Added: page
  ✅ Added: recordsPerPage
  ✅ Added: userGuid
  ... (69 more)

Converting inline parameters to $ref...
  Found 68 parameters available for conversion
  ✅ Converted 44 unique parameters to $ref
  📊 Total replacements: 352
  ⚠️  1 parameter not found in components (kept inline)
     Example: tax_document_guid (from extra path, will be removed in Phase 6)

Writing changes to: openapi/mx_platform_api.yml

============================================================
Parameter Synchronization Complete
============================================================
Phase 3a - Library Creation:
  Parameters added: 72
  Parameters removed: 0
  Parameters skipped: 0

Phase 3b - Inline Conversion:
  Converted to $ref: 44
  Not found (kept inline): 3

✅ Successfully updated openapi/mx_platform_api.yml

Next steps:
1. Review changes: git diff openapi/mx_platform_api.yml
2. Verify line count: wc -l openapi/mx_platform_api.yml
3. Validate: ruby tmp/compare_openapi_specs.rb | grep -i parameter
4. Test: redocly preview-docs openapi/mx_platform_api.yml
```

### Verify Results

```bash
# Check line changes (should show net reduction)
$ git diff --stat openapi/mx_platform_api.yml
 openapi/mx_platform_api.yml | 3224 +++++++++++++----------
 1 file changed, 879 insertions(+), 2345 deletions(-)

# Check file size reduction
$ wc -l openapi/mx_platform_api.yml
    8920 openapi/mx_platform_api.yml  # Down from 10,386 (14% reduction)

# Verify synchronization
$ ruby tmp/compare_openapi_specs.rb | grep -i parameter
  Missing parameters: 0
  Extra parameters (should remove): 0

# Check parameters section location
$ grep -n "^  parameters:" openapi/mx_platform_api.yml
5201:  parameters:

# View sample parameter in library
$ sed -n '5202,5210p' openapi/mx_platform_api.yml
    page:
      description: Specify current page.
      example: 1
      in: query
      name: page
      schema:
        type: integer

# Verify inline parameters were converted to $ref
$ grep -c "\$ref.*parameters" openapi/mx_platform_api.yml
352  # Should see 300+ $ref usages

# Check a specific conversion
$ sed -n '5771,5775p' openapi/mx_platform_api.yml
      parameters:
        - $ref: '#/components/parameters/page'
        - $ref: '#/components/parameters/recordsPerPage'
      responses:
        "200":
```

## Verification Steps

After running the script, perform these checks:

### 1. Structural Verification
```bash
# Ensure parameters section exists
grep -q "^  parameters:$" openapi/mx_platform_api.yml && echo "✅ Section exists"

# Check it's in the right location (before securitySchemes)
awk '/^  parameters:/{p=1} /^  securitySchemes:/{if(p) print "✅ Correct location"; exit}' openapi/mx_platform_api.yml
```

### 2. Indentation Verification
```bash
# Check parameter names are at 4-space indent
sed -n '/^  parameters:/,/^  [a-z]/p' openapi/mx_platform_api.yml | grep "^    [a-z]" | head -3

# Check parameter content is at 6-space indent
sed -n '/^  parameters:/,/^  [a-z]/p' openapi/mx_platform_api.yml | grep "^      " | head -3
```

### 3. Content Verification
```bash
# Verify all 72 parameters added (or expected count)
sed -n '/^  parameters:/,/^  securitySchemes:/p' openapi/mx_platform_api.yml | grep -c "^    [a-z]"

# Run comparison again to confirm 0 missing
ruby tmp/compare_openapi_specs.rb 2>&1 | grep "Missing parameters: 0"
```

### 4. OpenAPI Validation
```bash
# Validate with redocly
npx @redocly/openapi-cli lint openapi/mx_platform_api.yml

# Preview docs (check parameters render correctly)
npx @redocly/openapi-cli preview-docs openapi/mx_platform_api.yml
```

## Integration with Workflow

### Complete Synchronization Sequence

```bash
# 1. Phase 0: Setup (if needed)
ruby tmp/compare_openapi_specs.rb

# 2. Phase 1: Schemas
ruby tmp/sync_schemas.rb

# 3. Phase 2: Fields
ruby tmp/sync_fields.rb

# 4. Phase 3: Parameters ← THIS SCRIPT
ruby tmp/sync_parameters.rb

# 5. Phase 4: Paths (future)
# ruby tmp/sync_paths.rb

# 6. Verify complete synchronization
ruby tmp/compare_openapi_specs.rb
```

### Git Workflow

```bash
# Review changes
git diff openapi/mx_platform_api.yml

# Check statistics
git diff --stat openapi/mx_platform_api.yml

# Stage and commit
git add openapi/mx_platform_api.yml
git commit -m "feat(params): consolidate parameters to components.parameters

Phase 3a - Library Creation:
- Added 72 parameters to components.parameters section
- Created section before securitySchemes for proper structure
- Converted external refs to internal format

Phase 3b - Inline Conversion:
- Converted 352 inline parameter definitions to \$ref
- Affected 44 unique parameters across 144 operations
- 3 parameters kept inline (no match in parameters.yaml)

Net result: -1,466 lines (14% reduction)
File size: 10,386 → 8,920 lines

Verified: 0 missing parameters, 0 extra parameters"
```

## Safety Features

1. **Non-destructive creation**: Only creates `parameters:` section if it doesn't exist
2. **Validation**: Skips parameters not found in source (logs them)
3. **Pattern matching**: Uses Regexp.escape to safely handle special characters
4. **Clear output**: Shows exactly what was added/removed/skipped
5. **Rollback friendly**: Use `git checkout openapi/mx_platform_api.yml` to revert

## Known Limitations

1. **Trailing spaces**: Source parameters with trailing spaces after `:` are handled (regex pattern: `:[ ]?\n`)
2. **Parameter order**: New parameters are inserted at the beginning of the section (not alphabetically sorted)
3. **In-place modification**: File is overwritten; always commit previous work first
4. **No validation**: Script doesn't validate OpenAPI syntax; use redocly after running
5. **Unmatchable parameters**: Some inline parameters may not have matches in parameters.yaml:
   - These are typically typos or parameters from paths that will be removed (extra paths)
   - Examples fixed in Phase 3: `records_per_age` → `records_per_page`, `microdeposit_guid` → `micro_deposit_guid`
   - Example to be removed later: `tax_document_guid` (entire tax_documents paths are extra, removed in Phase 6)

## Lessons Learned During Development

### Phase 3b Conversion Challenges

**Issue 1: Regex Infinite Loop**
- **Problem**: Initial regex patterns with greedy matching caused script to hang
- **Solution**: Used precise lookahead `(?=^        - |^      \w+:|\z)` to stop at next parameter OR next operation section

**Issue 2: Set Not Available**
- **Problem**: Script failed with `uninitialized constant Set`
- **Solution**: Added `require 'set'` to dependencies (line 3)

**Issue 3: Capturing Too Much**
- **Problem**: Regex captured `tags:` section as part of parameter block
- **Solution**: Lookahead now stops at ANY 6-space keyword (`^      \w+:`), not just specific ones

**Issue 4: Verification**
- **Problem**: Script reported success but changes weren't visible
- **Solution**: Always verify with `git diff --stat` and line count before/after

### Performance Notes

- **Typical runtime**: 5-10 seconds for 10K+ line file
- **Memory usage**: Entire file loaded into memory (~1-2MB for typical OpenAPI spec)
- **Regex performance**: `gsub!` with lookaheads processes ~350 matches in <5 seconds

## Troubleshooting

### Issue: "Could not find parameter definition in parameters.yaml"

**Cause**: Parameter name in comparison doesn't match any parameter in source file

**Solution**:
```bash
# Check if parameter exists with different case or spelling
grep -i "parametername" openapi/parameters.yaml

# Verify comparison is up to date
ruby tmp/compare_openapi_specs.rb
```

### Issue: "Could not find securitySchemes or paths section"

**Cause**: Target file doesn't have expected OpenAPI structure

**Solution**:
```bash
# Verify components section exists
grep -n "^components:" openapi/mx_platform_api.yml

# Verify paths section exists
grep -n "^paths:" openapi/mx_platform_api.yml
```

### Issue: Parameters added but comparison still shows missing

**Cause**: Indentation is incorrect or YAML parsing failed

**Solution**:
```bash
# Check indentation of added parameters
sed -n '5200,5250p' openapi/mx_platform_api.yml

# Validate YAML syntax
ruby -ryaml -e "YAML.load_file('openapi/mx_platform_api.yml'); puts '✅ Valid YAML'"

# Check for tabs (should be spaces)
grep -P '\t' openapi/mx_platform_api.yml && echo "❌ Found tabs, use spaces"
```

### Issue: Script runs but 0 parameters added

**Cause**: comparison_diff.json doesn't have missing_parameters list

**Solution**:
```bash
# Regenerate comparison
ruby tmp/compare_openapi_specs.rb

# Check if parameters are actually missing
grep "missing_parameters" tmp/comparison_diff.json
```

### Issue: Script hangs during "Converting inline parameters"

**Cause**: Regex pattern causing infinite loop or excessive backtracking

**Solution**:
```bash
# This was fixed in the script, but if you encounter it:
# 1. Verify 'require set' is present (line 3)
# 2. Check regex lookahead stops at: (?=^        - |^      \w+:|\z)
# 3. Use timeout to detect: timeout 30 ruby tmp/sync_parameters.rb
```

### Issue: Parameters converted but tags/responses missing

**Cause**: Regex captured too much (beyond parameter block)

**Solution**:
```bash
# Check if lookahead is precise
grep -A 5 "parameters:" openapi/mx_platform_api.yml | head -20

# Should see:
#   parameters:
#     - $ref: '#/components/parameters/...'
#   responses:  ← Should be here, not missing
```

### Issue: Some parameters not converted (kept inline)

**Cause**: Parameter name in file doesn't match any in parameters.yaml

**Root causes:**
1. **Typos** in inline parameter names (fixed in Phase 3)
2. **Extra paths** that will be removed in later phases

**Examples and fixes**:
```bash
# Check if parameter exists in source
grep "records_per_page" openapi/parameters.yaml  # Will find it
grep "records_per_age" openapi/parameters.yaml   # Won't find it (typo)

# Fix typos before running Phase 3:
sed -i '' 's/records_per_age/records_per_page/g' openapi/mx_platform_api.yml
sed -i '' 's/microdeposit_guid/micro_deposit_guid/g' openapi/mx_platform_api.yml

# For parameters in "extra paths" (like tax_document_guid):
# - These will be removed when the paths are removed in Phase 6
# - Don't need to fix - entire paths will be deleted
# - Check comparison_report.md "Extra Paths" section to confirm
```

## Reusability for Future Versions

### Example: v20250224 Release

```bash
# 1. Generate comparison for new version
ruby tmp/compare_openapi_specs.rb \
  --models openapi/models_v20250224.yaml \
  --params openapi/parameters_v20250224.yaml \
  --paths openapi/v20250224.yaml \
  --output tmp/comparison_diff_v20250224.json

# 2. Run parameter sync for new version
ruby tmp/sync_parameters.rb \
  openapi/parameters_v20250224.yaml \
  openapi/mx_platform_api_v20250224.yml \
  tmp/comparison_diff_v20250224.json

# 3. Verify
ruby tmp/compare_openapi_specs.rb \
  --models openapi/models_v20250224.yaml \
  --params openapi/parameters_v20250224.yaml \
  --target openapi/mx_platform_api_v20250224.yml \
  | grep -i parameter
```

### Automation

Add to Makefile:
```makefile
.PHONY: sync-parameters
sync-parameters:
	@echo "Synchronizing parameters..."
	@ruby tmp/sync_parameters.rb
	@echo "✅ Parameters synchronized"
	@ruby tmp/compare_openapi_specs.rb | grep -i parameter
```

Usage:
```bash
make sync-parameters
```

## Related Documentation

- **SYNC_SCHEMAS_README.md** - Schema synchronization (Phase 1)
- **SYNC_FIELDS_README.md** - Field synchronization (Phase 2)
- **SYNC_WORKFLOW_README.md** - Complete workflow overview
- **comparison_report.md** - Human-readable diff report

---

**Last Updated**: 2025-10-22  
**Script Version**: tmp/sync_parameters.rb  
**Tested With**: Ruby 3.1.0, OpenAPI 3.0.0
