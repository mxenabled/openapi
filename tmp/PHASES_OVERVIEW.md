# OpenAPI Synchronization Project - Phases Overview

**Project Goal:** Achieve complete parity between `mx_platform_api.yml` and v20111101.yaml (docs-v2)

**Branch:** nn/devx-7466_phase0  
**Last Updated:** 2025-10-23

---

## Progress Summary

**Completed:** 6 of 9 phases (67%)  
**Remaining:** 3 phases (33%)

**Status:**
- ✅ Phase 0: Project Infrastructure
- ✅ Phase 1: Add Missing Schemas (35 schemas)
- ✅ Phase 2: Sync Schema Fields (15 added, 10 removed)
- ✅ Phase 3: Add Parameters & Convert Refs (72 params, 352 conversions)
- ✅ Phase 4: Sync Paths (25 added, 10 removed)
- ✅ Phase 5: Tag Synchronization (90 tags, 25 domains)
- ✅ Phase 6: Fix Structures & Remove Deprecated Schemas (9 removed)
- 📅 Phase 7: Fix Type Mismatches (3 fixes)
- 📅 Phase 8: Internalize External References (self-contained)
- 📅 Phase 9: Final Validation

---

## Completed Phases ✅

### Phase 0: Project Infrastructure
**Status:** ✅ Complete  
**Commit:** Initial setup

**Deliverables:**
- Ruby-only policy established
- Initial comparison tooling

**Key Decisions:**
- Ruby-only for all scripting (no Python, no JavaScript)
- Use yq for format-preserving YAML manipulation
- Incremental git checkpoints with validation

---

### Phase 1: Add Missing Schemas
**Status:** ✅ Complete  
**Commit:** 324c905  
**Date:** 2025-10-21

**Scope:** Add 35 missing schemas from models.yaml

**Results:**
- Added 35 complete schema definitions
- All schemas properly structured under components/schemas
- Zero reformatting issues using yq

**Schemas Added:** ACHResponse, ACHReturnCreateRequest, AccountNumberResponse, AccountOwnerResponse, AllVerifications, AuthorizationCodeRequest/Response, BudgetCreate/UpdateRequest, GoalRequest/Response, InsightResponse/UpdateRequest, InvestmentHoldingResponse, NotificationResponse, PaymentAccount, ProcessorAccountNumber/Owner/Transaction, RepeatingTransactionResponse, SpendingPlanAccount/Iteration/Response, and many more.

**Validation:**
- ✅ All 35 schemas present in mx_platform_api.yml
- ✅ Field counts match models.yaml exactly
- ✅ No formatting side effects

---

### Phase 2: Sync Schema Fields
**Status:** ✅ Complete  
**Commit:** 612bc07  
**Date:** 2025-10-21

**Scope:** Add 15 missing fields, remove 10 extra fields from existing schemas

**Results:**
- 15 fields added to existing schemas
- 10 extra fields removed (breaking changes)
- Format-preserving using yq

**Key Changes:**
- Added missing fields to schemas like MemberResponse, AccountResponse, etc.
- Removed deprecated/extra fields for parity
- Fixed field ordering and structure

**Validation:**
- ✅ Field counts match models.yaml
- ✅ All required fields present
- ✅ No unintended reformatting

---

### Phase 3: Add Missing Parameters & Convert Inline Refs
**Status:** ✅ Complete  
**Commit:** 34b1ed8  
**Date:** 2025-10-21

**Scope:** Add 72 missing parameters, convert 352 inline parameter definitions to $ref

**Results:**
- Added 72 parameters from parameters.yaml
- Converted 352 inline parameters → $ref: '#/components/parameters/...'
- Massive deduplication and standardization

**Parameters Added:**
- acceptHeader, accountGuid, achReturnGuid, budgetGuid
- categoryGuid, goalGuid, insightGuid, institutionCode
- memberGuid, merchantGuid, notificationGuid
- All query/path parameters properly defined
- Pagination, filtering, sorting parameters

**Impact:**
- Cleaner path definitions (no duplicate parameter definitions)
- Single source of truth for each parameter
- Easier maintenance and updates

**Validation:**
- ✅ 0 missing parameters
- ✅ 352 conversions successful
- ✅ All $ref pointers valid
- ✅ Format preserved (minimal whitespace changes)

---

### Phase 4: Sync API Paths
**Status:** ✅ Complete  
**Commit:** b4cafdb  
**Date:** 2025-10-22

**Scope:** Add 25 missing paths, remove 10 extra paths from mx_platform_api.yml

**Results:**
- File grew from 8,920 → 9,287 lines (+367 lines net)
- Path count: 99 → 114 paths
- Format-preserving using yq (no quote/date reformatting)

**Paths Added (25):**
- ACH Return endpoints (3): list, read, update
- Account verification endpoints (1)
- Category custom endpoints (6): create, read, update, delete, list by user
- Institution endpoints (4): favorites, read by code, get credentials
- Investment holdings endpoints (5): list by account, list by member, list by user, read, deactivate
- Managed data endpoint (1): upload
- Merchant endpoints (3): list, read, read location
- Notification endpoints (2): list, read
- Processor token endpoint (1): create
- Repeating transactions (2): list, read
- Spending plan iteration endpoint (1): current
- Transaction insights endpoint (1)
- User account/member transaction endpoint (1)

**Paths Removed (10):**
- /users/{user_guid}/accounts/{account_guid}/holdings
- /users/{user_guid}/accounts/{account_guid}/holdings/{holding_guid}
- /users/{user_guid}/holdings
- /users/{user_guid}/holdings/{holding_guid}
- /users/{user_guid}/members/{member_guid}/holdings
- /users/{user_guid}/tax_documents
- /users/{user_guid}/tax_documents/{tax_document_guid}
- /users/{user_guid}/{member_guid}/microdepsit
- /users/{user_guid}/{member_guid}/microdeposit_verify
- /users/{user_guid}/{member_guid}/verfiy_member

**Breaking Changes:**
- Holdings → Investment Holdings (renamed endpoints)
- Tax Documents removed entirely
- Typo fixes (verfiy → verify, microdepsit → microdeposit)

**Challenges Solved:**
- **Initial Problem:** Ruby YAML.dump reformatted entire file (3,735 line changes)
- **Solution:** Installed yq v4.48.1, rewrote script to use yq shell commands
- **Result:** Minimal changes (only path additions/removals + whitespace cleanup)

**External References Issue:**
- Discovered: Paths from v20111101.yaml contain external references (`$ref: './schemas/models.yaml#/...'`)
- Temporary fix: Created openapi/schemas/ directory with models.yaml and parameters.yaml copies
- Long-term: Need to internalize these references (future phase)

**Validation:**
- ✅ 0 missing paths (114 total, matches v20111101.yaml exactly)
- ✅ 0 extra paths
- ✅ Format preserved (no unwanted reformatting)
- ✅ Preview server operational

**Documentation Created:**
- tmp/sync_paths.rb (141 lines, yq-based)
- tmp/SYNC_PATHS_README.md (300+ lines)
- tmp/TECHNOLOGY_STACK.md (Ruby-only policy, YAML handling rules)

---

## Current State Summary

**File Statistics:**
- Current size: 9,287 lines
- Total schemas: 202 (all from models.yaml)
- Total parameters: 72 (all from parameters.yaml)
- Total paths: 114 (matches v20111101.yaml)

**Current Status:**
- ✅ All schemas present and complete
- ✅ All parameters present and referenced
- ✅ All paths synchronized
- ⚠️ Tags need synchronization (most use generic `mx_platform` tag)
- ⚠️ 9 extra schemas need removal (breaking)
- ⚠️ 3 type mismatches need fixing
- ⚠️ External references need internalization

**Preview Server:** http://127.0.0.1:8080 (operational with temporary schemas/ directory)

---

## Upcoming Phases 📋

### Phase 5: Tag Synchronization
**Status:** 🔄 Not Started (NEXT)  
**Priority:** HIGH - Critical for UX  
**Impact:** Non-breaking, documentation organization

**Problem:** 
Current mx_platform_api.yml uses generic `mx_platform` tag for most endpoints. This causes poor documentation navigation where most endpoints are lumped together under "mx_platform" instead of being logically grouped by domain.

**Current Tag Distribution:**
- **Specific tags** (properly grouped): insights, transactions, budgets, goals
- **Generic tag** (poorly grouped): mx_platform (contains users, categories, institutions, accounts, members, merchants, etc.)

**Correct Tag Structure (from v20111101.yaml):**
- users (user operations)
- categories (category operations)
- institutions (institution operations)
- accounts (account operations)
- members (member operations)
- merchants (merchant operations)
- transactions (transaction operations)
- insights (insight operations)
- budgets (budget operations)
- goals (goal operations)
- ach return (ACH return operations)
- managed data (managed data operations)
- processor token (processor token operations)
- And more domain-specific tags

**Action Items:**
1. Create tag comparison script (Ruby + yq)
2. Identify all tags in v20111101.yaml
3. Map tags to paths in mx_platform_api.yml
4. Replace generic `mx_platform` tags with specific domain tags
5. Verify no paths left untagged
6. Test preview server for improved navigation

**Expected Changes:**
- ~80-100 tag replacements (estimate based on path count)
- Format-preserving using yq
- No structural changes to paths
- Improved Swagger/Redoc UI organization

**Deliverables:**
- tmp/sync_tags.rb (Ruby script using yq)
- tmp/SYNC_TAGS_README.md (documentation)
- Updated mx_platform_api.yml with proper tags

**Validation:**
- [ ] All tags match v20111101.yaml
- [ ] No generic `mx_platform` tags remaining (or minimized)
- [ ] Preview server shows logical grouping
- [ ] Format preserved

**Estimated Impact:** Medium effort, high UX improvement

---

### Phase 6: Remove Extra Schemas (BREAKING)
**Status:** ✅ Complete  
**Commit:** Pending  
**Date:** 2025-10-23

**Scope:** Fix schema structures and remove 9 deprecated schemas

**What Was Done:**
1. Fixed 3 schema structures to match models.yaml:
   - RewardResponseBody: Now uses MemberElements + RewardElements (allOf)
   - RewardsResponseBody: Now uses MemberElements + RewardElements (allOf)
   - MicrodepositRequestBody: Now uses MicrodepositElements

2. Removed 9 deprecated schemas:
   - HoldingResponse, HoldingResponseBody, HoldingsResponseBody
   - MicrodepositRequest
   - RewardResponse, RewardsResponse
   - TaxDocumentResponse, TaxDocumentResponseBody, TaxDocumentsResponseBody

**Results:**
- 7 insertions, 250 deletions (257 lines changed)
- Schema count: 211 → 202 (-9 schemas)
- All deprecated schemas removed successfully
- Format preserved using yq

**Key Insight:**
This phase completed unfinished Phase 2 work. Some schemas added in Phase 1 had incorrect internal structures - they referenced deprecated child schemas instead of using the Elements composition pattern from models.yaml.

**Migration Impact:**
These schemas were already deprecated and not used in v20111101.yaml:
- Holdings replaced by InvestmentHoldings
- Rewards now use Elements composition
- TaxDocument feature removed entirely

**Validation:**
- ✅ All 9 deprecated schemas removed
- ✅ No broken $ref references
- ✅ Schema structures match models.yaml
- ✅ Format preserved

**Deliverables:**
- tmp/phase6_fix_and_remove.rb (Ruby script using yq)
- tmp/PHASE6_SUMMARY.md (detailed documentation)
- Updated mx_platform_api.yml
- [ ] Format preserved

---

### Phase 7: Fix Type Mismatches
**Status:** 📅 Not Started  
**Priority:** MEDIUM  
**Impact:** Data type consistency, potentially breaking

**Scope:** Fix 3 type mismatches between mx_platform_api.yml and models.yaml

**Type Mismatches to Fix:**

1. **MicrodepositVerifyRequest.deposit_amount_1**
   - Current: `integer`
   - Should be: `number`
   - Reason: Deposits can be fractional (cents)

2. **MicrodepositVerifyRequest.deposit_amount_2**
   - Current: `integer`
   - Should be: `number`
   - Reason: Deposits can be fractional (cents)

3. **MonthlyCashFlowResponse.estimated_goals_contribution**
   - Current: `integer`
   - Should be: `number`
   - Reason: Financial amounts should support decimals

**Action Items:**
1. Create type fix script (Ruby + yq)
2. Update field types in schema definitions
3. Verify no breaking changes to existing data
4. Update examples if needed

**Expected Changes:**
- 3 type changes (integer → number)
- Minimal line changes
- Format-preserving using yq

**Deliverables:**
- tmp/fix_types.rb (Ruby script using yq)
- tmp/TYPE_FIXES_README.md (documentation)
- Updated mx_platform_api.yml

**Validation:**
- [ ] All types match models.yaml
- [ ] No type mismatches remaining
- [ ] Examples valid for new types
- [ ] Format preserved

---

### Phase 8: Internalize External References
**Status:** 📅 Not Started  
**Priority:** MEDIUM - Required for self-contained spec  
**Impact:** Non-breaking, structural requirement

**Problem:**
During Phase 4, paths copied from v20111101.yaml included external file references because v20111101.yaml uses a split-file architecture. mx_platform_api.yml must be completely self-contained with all schemas in `#/components/schemas`.

**External References Currently Present:**
- `$ref: './schemas/models.yaml#/ProcessorAccountNumberBody'`
- `$ref: './schemas/models.yaml#/MemberResponseBody'`
- `$ref: './schemas/models.yaml#/ProcessorOwnerBody'`
- `$ref: './schemas/parameters.yaml#/...'` (possibly)
- And more (need to audit all paths added in Phase 4)

**Current Temporary Workaround:**
- Created openapi/schemas/ directory with copied model/parameter files
- Allows preview server to resolve external references
- **This directory should NOT be committed** - it's only for local preview
- Must be replaced with proper internal references

**Goal:**
Convert ALL external file references to internal component references for a completely self-contained specification:
- External: `$ref: './schemas/models.yaml#/SchemaName'`
- Internal: `$ref: '#/components/schemas/SchemaName'`

**Why Required:**
- mx_platform_api.yml must be self-contained (single file with all definitions)
- External references break portability and SDK generation
- The schemas/ directory is temporary for local preview only
- Requirement: specification should work without any external files

**Action Items:**
1. Audit mx_platform_api.yml for ALL external references (./schemas/*)
2. Verify all referenced schemas exist in components/schemas (they should from Phase 1)
3. Replace external refs with internal refs using yq (format-preserving)
4. Replace external parameter refs if any exist
5. Test preview server still works after changes
6. Delete temporary openapi/schemas/ directory
7. Add openapi/schemas/ to .gitignore to prevent accidental commits
8. Verify specification is truly self-contained

**Expected Changes:**
- ~10-25 reference updates (estimate based on 25 paths added in Phase 4)
- Delete openapi/schemas/ directory
- Add schemas/ to .gitignore
- Fully self-contained specification

**Deliverables:**
- tmp/internalize_refs.rb (Ruby script using yq)
- tmp/INTERNALIZE_REFS_README.md (documentation)
- Updated mx_platform_api.yml with all internal references
- Updated .gitignore

**Validation:**
- [ ] No external ./schemas/ references remain
- [ ] All $ref pointers valid and internal (#/components/...)
- [ ] Preview server works without schemas/ directory
- [ ] openapi/schemas/ directory deleted
- [ ] schemas/ added to .gitignore
- [ ] Format preserved
- [ ] Specification is completely self-contained

---

### Phase 9: Final Validation & Cleanup
**Status:** 📅 Not Started  
**Priority:** HIGH - Project completion  
**Impact:** Verification and documentation

**Scope:** Final comparison and verification of complete parity

**Action Items:**
1. Run final comparison: `ruby tmp/compare_openapi_specs.rb`
2. Verify 0 differences between mx_platform_api.yml and v20111101.yaml
3. Test SDK generation from updated specification
4. Update main README.md with synchronization details
5. Document any remaining known differences (if any)
6. Clean up tmp/ directory (archive scripts/docs)
7. Final commit and merge preparation

**Success Criteria:**
- [ ] 0 missing schemas
- [ ] 0 missing fields
- [ ] 0 missing parameters
- [ ] 0 missing paths
- [ ] 0 extra schemas
- [ ] 0 extra fields
- [ ] 0 extra parameters
- [ ] 0 extra paths
- [ ] 0 type mismatches
- [ ] 0 external references
- [ ] All tags properly synchronized
- [ ] SDK builds successfully
- [ ] Preview server shows complete, organized API

**Deliverables:**
- Final comparison report
- Updated README.md
- Merge-ready branch
- Complete documentation of changes

---

## Technical Notes

### Tools & Technologies
- **Ruby 3.1.0:** Only scripting language (strict policy)
- **yq v4.48.1:** YAML processor for format-preserving manipulation
- **Redocly CLI:** OpenAPI preview server
- **Git:** Version control with incremental checkpoints

### Key Decisions
1. **Ruby-only policy:** All scripts in Ruby (no Python, JavaScript)
2. **yq for YAML manipulation:** Preserves formatting, avoids Ruby YAML.dump reformatting
3. **Incremental changes:** Max 1-2 files per commit with validation
4. **Git checkpoints:** Commit after each phase for rollback capability
5. **Format preservation:** Avoid unwanted quote/date/whitespace changes

### Lessons Learned
- Ruby's YAML library (YAML.dump) reformats entire files → use yq instead
- External references from v20111101.yaml need temporary workarounds
- Tag-based organization critical for API documentation UX
- Breaking changes require coordination with SDK team

### Ruby-Only Enforcement
- All tmp/ scripts must use Ruby
- No Python scripts allowed (compare_openapi_specs.py removed)
- Use yq shell commands from Ruby via backticks or system()
- Document Ruby-only policy in TECHNOLOGY_STACK.md

---

## Progress Tracking

**Overall Progress:** 4/9 phases complete (44%)

**Completed:** ✅✅✅✅  
**In Progress:** (None)  
**Not Started:** ⬜⬜⬜⬜⬜

**Phase Status:**
- ✅ Phase 0: Infrastructure
- ✅ Phase 1: Add Schemas (35 added)
- ✅ Phase 2: Sync Fields (15 added, 10 removed)
- ✅ Phase 3: Add Parameters (72 added, 352 conversions)
- ✅ Phase 4: Sync Paths (25 added, 10 removed)
- 🔄 Phase 5: Tag Synchronization (NEXT)
- ⬜ Phase 6: Remove Extra Schemas (breaking)
- ⬜ Phase 7: Fix Type Mismatches
- ⬜ Phase 8: Internalize References
- ⬜ Phase 9: Final Validation

---

## Success Metrics

**Current Metrics:**
- Schemas: 202/202 ✅ (100%)
- Parameters: 72/72 ✅ (100%)
- Paths: 114/114 ✅ (100%)
- Tags: ~20/~100 ⚠️ (20% - needs Phase 5)
- Extra schemas: 9 remaining ⚠️
- Type mismatches: 3 remaining ⚠️

**Target Metrics (Complete):**
- Schemas: 100% match ✅
- Parameters: 100% match ✅
- Paths: 100% match ✅
- Tags: 100% match 🎯
- Extra schemas: 0 🎯
- Type mismatches: 0 🎯
- External references: 0 🎯

---

## Contact & Support

**Branch:** nn/devx-7466_phase0  
**Repository:** mxenabled/openapi  
**Documentation:** tmp/ directory (scripts, READMEs, reports)  
**Preview Server:** http://127.0.0.1:8080

**Key Files:**
- `/tmp/comparison_report.md` - Detailed difference report
- `/tmp/TECHNOLOGY_STACK.md` - Ruby-only policy and YAML rules
- `/tmp/PHASES_OVERVIEW.md` - This document
- `/openapi/mx_platform_api.yml` - Primary deliverable (9,287 lines)

---

*Last updated: 2025-10-22*
*Next action: Execute Phase 5 (Tag Synchronization)*
