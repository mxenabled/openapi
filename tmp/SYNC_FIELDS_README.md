# Field Synchronization Script

## Purpose

`sync_fields.rb` synchronizes schema fields between docs-v2 reference files (models.yaml) and the OpenAPI specification (mx_platform_api.yml), achieving **exact parity** by:

- ✅ **Adding** missing fields from models.yaml to mx_platform_api.yml
- ❌ **Removing** extra fields from mx_platform_api.yml not in models.yaml

## Usage

### Default (Current Version)

```bash
ruby tmp/sync_fields.rb
```

Uses default paths:
- Source: `openapi/models.yaml`
- Target: `openapi/mx_platform_api.yml`
- Diff: `tmp/comparison_diff.json`

### Future Versions (e.g., v20250224)

```bash
ruby tmp/sync_fields.rb openapi/models_v20250224.yaml openapi/mx_platform_api.yml tmp/comparison_diff.json
```

## Prerequisites

1. **Run comparison script first** to generate `comparison_diff.json`:
   ```bash
   ruby tmp/compare_openapi_specs.rb
   ```

2. **Verify the diff** to understand what will change:
   ```bash
   cat tmp/comparison_report.md
   ```

## What It Does

### Step-by-Step Process

1. **Reads comparison_diff.json** - Gets list of schemas with field differences
2. **Loads source files** - Reads models.yaml and mx_platform_api.yml
3. **Processes each schema**:
   - **Removes extra fields** (8-space indent under `properties:`)
   - **Adds missing fields** (extracts from models.yaml, converts $ref, adds proper indentation)
4. **Writes updated file** - Saves changes to mx_platform_api.yml
5. **Reports statistics** - Shows counts of modified schemas, added/removed fields

### Field Processing Details

**Removal Pattern:**
- Matches fields at 8-space indentation (under `properties:`)
- Removes field name line and all nested content (10+ space indent)
- Regex: `/^        #{field_name}:\s*\n((?:          .+\n)*)/`

**Addition Pattern:**
- Extracts field from models.yaml (4-space indent for fields)
- Adds 4 spaces for mx_platform_api.yml format (8-space total)
- Converts external `$ref: '#/SchemaName'` → `$ref: '#/components/schemas/SchemaName'`
- Inserts at end of `properties:` section

## Example Output

```
======================================================================
Field Synchronization: Add Missing & Remove Extra Fields
======================================================================

[1/7] Reading tmp/comparison_diff.json...
Schemas with missing fields: 8
Schemas with extra fields:   4
Total schemas to modify:     12

[2/7] Reading source files...
✅ Loaded openapi/models.yaml and openapi/mx_platform_api.yml

[3/7] Processing schemas...

  📝 ConnectWidgetRequest
     Missing: 1 fields
     ✅ Added: enable_app2app

  📝 ImageOptionResponse
     Extra:   1 fields
     ❌ Removed: guid

  📝 MicrodepositResponse
     Extra:   7 fields
     ❌ Removed: account_name
     ❌ Removed: account_number
     ❌ Removed: account_type
     ❌ Removed: email
     ❌ Removed: first_name
     ❌ Removed: last_name
     ❌ Removed: routing_number

[4/7] Writing updated openapi/mx_platform_api.yml...
✅ File updated

======================================================================
✅ Field Synchronization Complete!
======================================================================
Schemas modified:    12
Fields added:        15
Fields removed:      10
Schemas skipped:     0
======================================================================
```

## Verification

After running, verify the changes:

```bash
# 1. Review git diff
git diff openapi/mx_platform_api.yml

# 2. Re-run comparison to verify 0 field differences
ruby tmp/compare_openapi_specs.rb

# 3. Check field counts
ruby tmp/compare_openapi_specs.rb 2>&1 | grep -i field

# Expected output after successful sync:
#   Schemas with Missing Fields: 0
#   Schemas with Extra Fields:   0
```

## Integration with Workflow

**Phase 2 in overall synchronization process:**

1. **Phase 1**: Add missing schemas (`sync_schemas.rb`) ✅
2. **Phase 2**: Add/remove fields (`sync_fields.rb`) ✅ ← **THIS SCRIPT**
3. Phase 3: Add missing parameters (`sync_parameters.rb`)
4. Phase 4: Add missing paths (`sync_paths.rb`)
5. Phase 5: Remove extra schemas (breaking change)
6. Phase 6: Remove extra paths (breaking change)

## Safety Features

- ✅ **Dry-run capable** - Review `comparison_diff.json` before running
- ✅ **Git-friendly** - Preserves formatting, easy to review changes
- ✅ **Duplicate detection** - Skips fields that already exist
- ✅ **Schema validation** - Skips if schema not found in target
- ✅ **Comprehensive logging** - Shows every addition and removal

## Known Limitations

1. **Assumes standard indentation**:
   - 4 spaces for schema level
   - 6 spaces for `properties:`
   - 8 spaces for field names
   - 10 spaces for field attributes

2. **Does not handle**:
   - Field reordering (preserves existing order)
   - Type changes (only adds/removes complete fields)
   - Description updates (only adds/removes complete fields)

3. **Breaking changes**:
   - Removing fields may break API contracts
   - Always review removals carefully before committing

## Reusability for v20250224

When new docs-v2 version arrives:

```bash
# 1. Run comparison with new files
ruby tmp/compare_openapi_specs.rb \
  models_v20250224.yaml \
  parameters_v20250224.yaml \
  v20250224.yaml \
  mx_platform_api.yml

# 2. Run field sync with new model file
ruby tmp/sync_fields.rb \
  openapi/models_v20250224.yaml \
  openapi/mx_platform_api.yml \
  tmp/comparison_diff.json

# 3. Verify and commit
git diff openapi/mx_platform_api.yml
git add openapi/mx_platform_api.yml
git commit -m "feat(api): sync fields with models v20250224"
```

## Troubleshooting

**"Schema not found in mx_platform_api.yml"**
- Schema exists in models.yaml but not in target
- Run `sync_schemas.rb` first to add missing schemas

**"Pattern did not match for removal"**
- Field might have non-standard indentation
- Check actual spacing with `cat -A` or `sed 's/ /·/g'`

**"Already exists (skipping)"**
- Field is already present in target schema
- This is normal if running script multiple times
- No action needed

**No fields modified (0/0/0)**
- comparison_diff.json shows no field differences
- Either already synchronized or comparison needs re-run

## Success Criteria

After successful Phase 2:
- ✅ Missing fields: 0
- ✅ Extra fields: 0
- ✅ Git diff shows only field additions/removals (no formatting changes)
- ✅ OpenAPI validates successfully
- ✅ Preview renders correctly

---

**Last updated**: 2025-10-22  
**Author**: AI Agent (Claude Code Sonnet 4.5)  
**Version**: 1.0 (Production Ready)
