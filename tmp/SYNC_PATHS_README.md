# Path Synchronization Script

## Purpose

The `sync_paths.rb` script synchronizes API paths between `v20111101.yaml` (reference) and `mx_platform_api.yml` (target). It performs two operations atomically:

1. **Part 1**: Adds missing paths from v20111101.yaml
2. **Part 2**: Removes extra paths from mx_platform_api.yml (BREAKING)

## Usage

```bash
ruby tmp/sync_paths.rb
```

## What It Does

### Part 1: Add Missing Paths
- Identifies paths in v20111101.yaml that don't exist in mx_platform_api.yml
- Copies entire path definitions (all methods and operations)
- Preserves original structure and formatting from reference file

### Part 2: Remove Extra Paths (BREAKING)
- Identifies paths in mx_platform_api.yml that don't exist in v20111101.yaml
- Removes these paths completely
- **WARNING**: This is a breaking change - removes functionality

### Post-Processing
- Sorts all paths alphabetically for consistency
- Maintains proper YAML structure
- Preserves all other sections (components, schemas, etc.)

## Expected Results

Based on comparison_report.md analysis:

**Before Phase 4:**
- v20111101.yaml paths: 114
- mx_platform_api.yml paths: 99
- Missing paths: 25
- Extra paths: 10

**After Phase 4:**
- mx_platform_api.yml paths: 114
- Missing paths: 0
- Extra paths: 0

## Paths Added (25)

New paths from v20111101.yaml:

1. `/account/account_numbers` - GET account numbers
2. `/account/check_balance` - POST check balance
3. `/account/transactions` - GET transactions
4. `/ach_returns` - GET, POST ACH returns
5. `/ach_returns/{ach_return_guid}` - GET specific ACH return
6. `/micro_deposits/{micro_deposit_guid}/verify` - PUT verify microdeposit
7. `/payment_account` - GET payment account
8. `/tokens` - GET tokens
9. `/users/{user_guid}/account_verifications` - GET account verifications
10. `/users/{user_guid}/accounts/{account_guid}/investment_holdings` - GET investment holdings by account
11. `/users/{user_guid}/insights/{insight_guid}` - GET, PUT specific insight (fixed path)
12. `/users/{user_guid}/investment_holdings` - GET all investment holdings
13. `/users/{user_guid}/investment_holdings/{holding_guid}` - GET specific investment holding
14. `/users/{user_guid}/investment_holdings_deactivate` - GET deactivated holdings
15. `/users/{user_guid}/members/{member_guid}/accounts/{account_guid}/transactions/{transaction_guid}` - PUT update transaction
16. `/users/{user_guid}/members/{member_guid}/investment_holdings` - GET investment holdings by member
17. `/users/{user_guid}/notifications` - GET, POST notifications
18. `/users/{user_guid}/notifications/{notification_guid}` - GET specific notification
19. `/users/{user_guid}/repeating_transactions` - GET repeating transactions
20. `/users/{user_guid}/repeating_transactions/{repeating_transaction_guid}` - GET specific repeating transaction
21. `/users/{user_guid}/spending_plans/{spending_plan_guid}/iterations/current` - GET current iteration
22. `/users/{user_guid}/transactions/{transaction_guid}/insights` - GET transaction insights
23. `/vc/users/{user_guid}/accounts/{account_guid}/transactions` - GET VC transactions
24. `/vc/users/{user_guid}/members/{member_guid}/accounts` - GET VC accounts
25. `/vc/users/{user_guid}/members/{member_guid}/customers` - GET VC customers

## Paths Removed (10) - BREAKING CHANGES

Removed paths that don't exist in v20111101.yaml:

1. `/micro_deposits/{microdeposit_guid}/verify` - PUT verify (typo: microdeposit vs micro_deposit)
2. `/users/{user_guid}/accounts/{account_guid}/holdings` - GET holdings (replaced by investment_holdings)
3. `/users/{user_guid}/holdings` - GET holdings (replaced by investment_holdings)
4. `/users/{user_guid}/holdings/{holding_guid}` - GET specific holding (replaced by investment_holdings)
5. `/users/{user_guid}/insights{insight_guid}` - GET, PUT insight (typo: missing slash)
6. `/users/{user_guid}/members/{member_guid}/fetch_tax_documents` - POST fetch tax docs
7. `/users/{user_guid}/members/{member_guid}/holdings` - GET holdings by member (replaced by investment_holdings)
8. `/users/{user_guid}/members/{member_guid}/tax_documents` - GET tax documents
9. `/users/{user_guid}/members/{member_guid}/tax_documents/{tax_document_guid}` - GET specific tax document
10. `/users/{user_guid}/members/{member_guid}/tax_documents/{tax_document_guid}.pdf` - GET tax document PDF

## Breaking Changes Impact

### Holdings → Investment Holdings Renaming
- Old: `/holdings` endpoints
- New: `/investment_holdings` endpoints
- **Impact**: SDK methods need renaming, client code must update

### Tax Documents Removal
- 4 tax_documents endpoints removed entirely
- **Impact**: Feature no longer available via API

### Path Typo Fixes
- `/insights{insight_guid}` → `/insights/{insight_guid}` (fixed)
- `/microdeposit_guid` → `/micro_deposit_guid` (parameter name fix)

## Verification

```bash
# Verify path count
ruby tmp/compare_openapi_specs.rb | grep -A 5 "Path"

# Expected output:
#   Missing paths: 0
#   Extra paths: 0
#   Common paths: 114

# Check specific new paths
grep -E "^  \"/(ach_returns|investment_holdings|notifications)\":" openapi/mx_platform_api.yml

# Verify removed paths are gone
grep -E "^  \"/(holdings|tax_documents)\":" openapi/mx_platform_api.yml
# Should return no matches
```

## File Changes

**Modified:**
- `openapi/mx_platform_api.yml` - Added 25 paths, removed 10 paths, sorted all paths
  - Before: 99 paths, ~8,920 lines
  - After: 114 paths, ~9,287 lines (+367 lines net)

## Integration with Other Phases

**Prerequisites:**
- Phase 0: AI project structure ✅
- Phase 1: Schema synchronization ✅
- Phase 2: Field synchronization ✅
- Phase 3: Parameter synchronization ✅

**Next Steps:**
- Phase 5: Remove extra schemas (BREAKING)
- Phase 6: Final cleanup and validation

## Script Features

- **Atomic Operation**: Both add and remove in single run
- **Path Normalization**: Handles leading/trailing slashes
- **Alphabetical Sorting**: Ensures consistent path order
- **Safe YAML Loading**: Handles Time, Date, Symbol objects
- **Comprehensive Output**: Shows exactly what changed
- **Error Handling**: Validates file loading and saving

## Known Limitations

1. **No Rollback**: Changes are immediate (use git to revert)
2. **Breaking Changes**: Part 2 removes functionality (coordinate with SDKs)
3. **No Conflict Resolution**: Assumes clean paths (no duplicate definitions)
4. **Full Path Copy**: Copies entire path definitions (no granular method merging)

## Troubleshooting

### Script Won't Run

**Error**: `uninitialized constant Date`
**Fix**: Added `require 'date'` to script

**Error**: `Tried to load unspecified class: Time`
**Fix**: Added `permitted_classes: [Time, Date, Symbol]` to YAML.load_file

### Paths Not Matching

**Issue**: Path count still shows mismatches
**Check**:
```bash
# Compare normalized path keys
ruby -ryaml -e "puts YAML.load_file('openapi/v20111101.yaml', permitted_classes: [Time, Date, Symbol])['paths'].keys.sort"
ruby -ryaml -e "puts YAML.load_file('openapi/mx_platform_api.yml', permitted_classes: [Time, Date, Symbol])['paths'].keys.sort"
```

### Large Diff Size

**Observation**: +2,051 insertions, -1,684 deletions
**Explanation**:
- Added 25 complete path definitions with all methods
- Removed 10 path definitions
- Alphabetical resorting moved many existing paths
- Net effect: +367 lines actual growth

## Performance

- **Runtime**: ~2-3 seconds on standard hardware
- **Memory**: Loads both full YAML files into memory
- **File Size**: mx_platform_api.yml: 8,920 → 9,287 lines

## Git Commit Message

```
feat(paths): sync API paths with v20111101.yaml reference

Phase 4: Path Synchronization (BREAKING)

Added 25 missing paths:
- ACH returns endpoints (2 paths)
- Investment holdings endpoints (6 paths)
- Notifications endpoints (2 paths)
- Repeating transactions endpoints (2 paths)
- VC endpoints (3 paths)
- Account verifications, tokens, payment accounts
- Transaction insights, spending plan current iteration

Removed 10 extra paths (BREAKING):
- Holdings endpoints → replaced by investment_holdings (4 paths)
- Tax documents endpoints (4 paths)
- Fixed path typos: insights{insight_guid} → insights/{insight_guid}
- Fixed parameter typo: microdeposit_guid → micro_deposit_guid

Net result: +367 lines (9,287 total)
Path count: 99 → 114 (matches v20111101.yaml)

Breaking Changes:
- Holdings API renamed to Investment Holdings
- Tax documents feature removed
- Clients must update SDK method calls

Verification: 0 missing paths, 0 extra paths

Related: DEVX-7466
```

## References

- **Comparison Report**: `tmp/comparison_report.md`
- **Reference Spec**: `openapi/v20111101.yaml`
- **Target Spec**: `openapi/mx_platform_api.yml`
- **Verification Script**: `tmp/compare_openapi_specs.rb`

---

*Last updated: 2025-10-22*
*Phase 4 Status: Complete ✅*
