# Schema Synchronization Script

## Overview

`sync_schemas.rb` is a dynamic, reusable script that synchronizes schemas between `models.yaml` (source of truth) and `mx_platform_api.yml` (consolidated OpenAPI file).

## Features

- ✅ **Fully Dynamic**: Reads from `comparison_diff.json` (no hardcoded lists)
- ✅ **Robust Parsing**: Handles trailing spaces in YAML keys (`SchemaName: ` vs `SchemaName:`)
- ✅ **Format Preserving**: Maintains existing file formatting and structure
- ✅ **Reference Conversion**: Automatically converts external `$ref: '#/SchemaName'` to internal `$ref: '#/components/schemas/SchemaName'`
- ✅ **Safe Insertion**: Inserts before `securitySchemes:` to maintain proper structure
- ✅ **Detailed Reporting**: Shows exactly what was added, skipped, or not found
- ✅ **Reusable**: Can be run multiple times, for different documentation versions (v20111101, v20250224, etc.)

## Prerequisites

1. Run the comparison script first to generate the comparison report:
   ```bash
   ruby tmp/compare_openapi_specs.rb
   ```
   
   This creates:
   - `tmp/comparison_diff.json` (used by sync_schemas.rb)
   - `tmp/comparison_report.md` (human-readable)

## Usage

### Basic Usage

```bash
ruby tmp/sync_schemas.rb
```

### Expected Output

```
======================================================================
Schema Synchronization: Dynamic Schema Addition
======================================================================

[1/6] Reading comparison_diff.json...
Found 35 missing schemas in comparison report

   1. ACHResponse
   2. ACHReturnCreateRequest
   ...
  35. VCResponse

[2/6] Reading models.yaml...
✅ Loaded models.yaml (1234 lines)

[3/6] Reading mx_platform_api.yml...
✅ Found 177 existing schemas

[4/6] Extracting schemas from models.yaml...
  ✅ ACHResponse                            (29 lines)
  ✅ ACHReturnCreateRequest                 (16 lines)
  ...
  ✅ VCResponse                             (2 lines)

[5/6] Extraction Summary:
  ✅ Added:     35
  ⏭️  Skipped:   0
  ❌ Not found: 0

[6/6] Inserting schemas into mx_platform_api.yml...
✅ Insertion point: line 4155 (before securitySchemes:)
✅ Writing updated mx_platform_api.yml...

======================================================================
✅ Schema Synchronization Complete!
======================================================================
Schemas added:      35
Lines added:        ~1002
Schemas skipped:    0 (already exist)
Schemas not found:  0
======================================================================

📋 Next Steps:
  1. Review changes: git diff openapi/mx_platform_api.yml
  2. Re-run comparison: ruby tmp/compare_openapi_specs.rb
  3. Verify: ruby tmp/compare_openapi_specs.rb 2>&1 | grep 'Missing schemas:'
```

## Workflow for New Documentation Versions

When synchronizing a new documentation version (e.g., v20250224):

```bash
# 1. Update comparison script to point to new version files
# Edit tmp/compare_openapi_specs.rb:
#   - Update load_yaml('models_v20250224.yaml')
#   - Update load_yaml('parameters_v20250224.yaml')
#   - Update load_yaml('v20250224.yaml')

# 2. Run comparison to identify differences
ruby tmp/compare_openapi_specs.rb

# 3. Review the comparison report
cat tmp/comparison_report.md

# 4. Run schema synchronization
ruby tmp/sync_schemas.rb

# 5. Verify no missing schemas remain
ruby tmp/compare_openapi_specs.rb 2>&1 | grep "Missing schemas:"
# Expected: "Missing schemas: 0"

# 6. Review changes
git diff openapi/mx_platform_api.yml

# 7. Commit
git add openapi/mx_platform_api.yml
git commit -m "feat(api): sync schemas from v20250224"
```

## How It Works

### 1. Read Comparison Report
Parses `tmp/comparison_diff.json` to get list of missing schemas dynamically.

### 2. Check Existing Schemas
Scans `mx_platform_api.yml` for existing schemas to avoid duplicates.

### 3. Extract from Source
For each missing schema:
- Uses regex to extract from `models.yaml`: `/^SchemaName:[ ]?\n((?:  .+\n)*)/`
- Handles trailing spaces after colon
- Captures all indented content (2+ spaces)

### 4. Transform Content
- Adds 4 spaces to all lines (for `components.schemas` nesting)
- Converts external refs: `$ref: '#/SchemaName'` → `$ref: '#/components/schemas/SchemaName'`

### 5. Insert at Correct Position
- Finds insertion point: before `  securitySchemes:`
- Inserts all schemas at once
- Maintains file structure and formatting

### 6. Write and Report
- Writes updated file
- Provides detailed summary of changes

## Edge Cases Handled

✅ **Trailing Spaces**: `SchemaName: ` vs `SchemaName:`  
✅ **Already Exists**: Skips schemas already in target file  
✅ **Not Found**: Reports schemas listed in comparison but missing from source  
✅ **Reference Formats**: Handles quoted and unquoted `$ref`  
✅ **Empty Results**: Gracefully exits if no schemas to add  

## Troubleshooting

### "No such file or directory - tmp/comparison_diff.json"
**Solution**: Run `ruby tmp/compare_openapi_specs.rb` first

### "Could not find insertion point (securitySchemes:)"
**Solution**: Verify `mx_platform_api.yml` has `  securitySchemes:` section

### "Schema not found in models.yaml"
**Cause**: Schema listed in comparison report but doesn't exist in source file  
**Action**: Verify schema name spelling, check alternative source files

### Script reports "0 schemas to add" but comparison shows missing schemas
**Cause**: Schemas were already added in previous run  
**Action**: Re-run comparison to get updated numbers

## File Structure

```
tmp/
├── compare_openapi_specs.rb    # Generates comparison reports
├── comparison_diff.json        # JSON diff (input for sync_schemas.rb)
├── comparison_report.md        # Human-readable report
└── sync_schemas.rb             # This script (schema synchronization)

openapi/
├── models.yaml                 # Source of truth for schemas
├── parameters.yaml             # Source for parameters
├── v20111101.yaml             # Source for paths
└── mx_platform_api.yml        # Target consolidated file
```

## Maintenance

### For Future Documentation Versions

This script is designed to be version-agnostic. To use with new versions:

1. Update `compare_openapi_specs.rb` to point to new source files
2. Run comparison
3. Run this script
4. No changes to `sync_schemas.rb` needed!

### Script Dependencies

- Ruby 3.x
- JSON library (standard library)
- No external gems required

## Version History

- **v1.0** (2025-10-22): Initial consolidated script
  - Combines functionality of `add_missing_schemas_v2.rb` and `add_remaining_schemas.rb`
  - Fully dynamic (reads from comparison report)
  - Handles trailing spaces in YAML keys
  - Comprehensive error handling and reporting

## Author

Created for MX Platform API documentation synchronization (DEVX-7466)
