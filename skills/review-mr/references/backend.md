---
Distilled 2026-09-07 from gitlab-org/gitlab `doc/development/` at commit 718b5cb265bf (2026-08-31), read from ~/repo/gitlab-development-kit/gitlab. Source of truth is the docs, not this file: when an item fires during a review, open the local doc file it cites (or the public URL) and read that section in full before recording a verdict. Refresh this file when the docs change; record the new commit here.
---

# General and backend review checklists (gitlab-org/gitlab docs)

**Source pointer convention.** `doc/development/<path>.md#<anchor>` maps to `https://docs.gitlab.com/development/<path>/#<anchor>`. Files named `_index.md` map to the directory URL (for example `doc/development/fe_guide/_index.md` → `https://docs.gitlab.com/development/fe_guide/`).

## Part A — General / backend review (`doc/development/code_review.md` and `contributing/merge_request_workflow.md`)

### A1. Acceptance checklist (verbatim)

Source: `doc/development/code_review.md#acceptance-checklist` — `https://docs.gitlab.com/development/code_review/#acceptance-checklist`

Preamble (verbatim): "This checklist encourages the authors, reviewers, and maintainers of merge requests (MRs) to confirm changes were analyzed for high-impact risks to quality, performance, reliability, security, observability, and maintainability."

#### Quality — `code_review.md#quality`

1. You have self-reviewed this MR per code review guidelines.
2. The code follows the [software design guidelines](software_design.md).
3. Ensure [automated tests](testing_guide/_index.md) exist following the [testing pyramid](testing_guide/testing_levels.md). Add missing tests or create an issue documenting testing gaps.
4. You have considered the technical impacts on GitLab.com, Dedicated, and self-managed.
5. You have considered the impact of this change on the frontend, backend, and database portions of the system where appropriate and applied the `~ux`, `~frontend`, `~backend`, and `~database` labels accordingly.
6. You have tested this MR in [all supported browsers](../install/requirements.md#supported-web-browsers), or determined that this testing is not needed.
7. You have confirmed that this change is [backwards compatible across updates](multi_version_compatibility.md), or you have decided that this does not apply.
8. You have properly separated [EE content](ee_features.md) (if any) from FOSS. Consider [running the CI pipelines in a FOSS context](ee_features.md#run-ci-pipelines-in-a-foss-context).
9. You have considered that existing data may be surprisingly varied. For example, if adding a new model validation, consider making it optional on existing data.
10. You have fixed flaky tests related to this MR, or have explained why they can be ignored. Flaky tests have error `Flaky test '<path/to/test>' was found in the list of files changed by this MR.` but can be in jobs that pass with warnings.

#### Performance, reliability, and availability — `code_review.md#performance-reliability-and-availability`

1. You are confident that this MR does not harm performance, or you have asked a reviewer to help assess the performance impact. ([Merge request performance guidelines](merge_request_concepts/performance.md))
2. You have added [information for database reviewers in the MR description](database_review.md#required), or you have decided that it is unnecessary.
   - [Does this MR have database-related changes?](database_review.md)
3. You have considered the availability and reliability risks of this change.
4. You have considered the scalability risk based on future predicted growth.
5. You have considered the performance, reliability, and availability impacts of this change on large customers who may have significantly more data than the average customer.
6. You have considered the performance, reliability, and availability impacts of this change on customers who may run GitLab on the [minimum system](../install/requirements.md).
7. You are confident that this change is compatible with the [Cells architecture](cells/_index.md). For more information, see [Cells development principles](cells/_index.md#cells-development-principles).

#### Observability instrumentation — `code_review.md#observability-instrumentation`

1. You have included enough instrumentation to facilitate debugging and proactive performance improvements through observability. See [example](https://gitlab.com/gitlab-org/gitlab/-/issues/346124#expectations) of adding feature flags, logging, and instrumentation.

#### Documentation — `code_review.md#documentation`

1. You have included changelog trailers, or you have decided that they are not needed.
   - [Does this MR need a changelog?](changelog.md#what-warrants-a-changelog-entry)
2. You have added/updated documentation or decided that documentation changes are unnecessary for this MR.
   - [Is documentation required?](documentation/workflow.md#documentation-for-a-product-change)

#### Security — `code_review.md#security`

1. You have confirmed that if this MR contains changes to processing or storing of credentials or tokens, authorization, and authentication methods, or other items described in [the security review guidelines](https://handbook.gitlab.com/handbook/security/product-security/security-platforms-architecture/application-security/appsec-reviews/#what-should-be-reviewed), you have added the `~security` label and you have `@`-mentioned `@gitlab-com/gl-security/appsec`.
2. You have reviewed the documentation regarding [internal application security reviews](https://handbook.gitlab.com/handbook/security/product-security/security-platforms-architecture/application-security/appsec-reviews/#internal-application-security-reviews) for **when** and **how** to request a security review and requested a security review if this is warranted for this change.
3. If there are security scan results that are blocking the MR (due to the [merge request approval policies](https://gitlab.com/gitlab-com/gl-security/security-policies)):
   - For true positive findings, they should be corrected before the merge request is merged. This will remove the AppSec approval required by the merge request approval policy.
   - For false positive findings, something that should be discussed for risk acceptance, or anything questionable, ping `@gitlab-com/gl-security/appsec`.

#### Deployment — `code_review.md#deployment`

1. You have considered using a feature flag for this change because the change may be high risk.
2. If you are using a feature flag, you plan to test the change in staging before you test it in production, and you have considered rolling it out to a subset of production customers before rolling it out to all customers.
   - [When to use a feature flag](https://handbook.gitlab.com/handbook/product-development/how-we-work/product-development-flow/feature-flag-lifecycle/#when-to-use-feature-flags)
3. You have informed the Infrastructure department of a default setting or new setting change per [definition of done](contributing/merge_request_workflow.md#definition-of-done), or decided that this is unnecessary.

#### Compliance — `code_review.md#compliance`

1. You have confirmed that the correct [MR type label](labels/_index.md) has been applied.

### A2. Reviewer and maintainer responsibilities; review turnaround

Source: `code_review.md#the-responsibility-of-the-reviewer` — `https://docs.gitlab.com/development/code_review/#the-responsibility-of-the-reviewer`

- "Reviewers are responsible for reviewing the specifics of the chosen solution."
- **Turnaround:** "If unavailable within the [Review-response SLO](https://handbook.gitlab.com/handbook/engineering/workflow/code-review/#review-response-slo), inform the author, find a replacement using the [Review Workload Dashboard](https://gitlab-org.gitlab.io/gitlab-roulette/), and assign them." (The numeric SLO is defined in the handbook, not in this doc.)
- **When to approve:** "When confident the MR meets all [contribution acceptance criteria](contributing/merge_request_workflow.md#contribution-acceptance-criteria): 1. Select **Approve**. 2. `@` mention the author to notify them. 3. Request a review from a maintainer with [domain expertise](#domain-experts), or follow the [Reviewer roulette](#reviewer-roulette) suggestion."

Source: `code_review.md#the-responsibility-of-the-maintainer`

- Maintainers "are responsible for the overall health, quality, and consistency of the GitLab codebase. Their reviews focus on architecture, code organization, separation of concerns, tests, DRYness, consistency, and readability."
- "Maintainers are the DRI for ensuring MRs reasonably meet acceptance criteria."
- "If a maintainer feels that an MR is not able to merged, it is their responsibility to say so. The maintainer is also the expert adviser who knows when to pull in others for a second opinion."
- "When a maintainer approves an MR, they are taking responsibility alongside the author. This means that when there is a production incident, the maintainer may get paged to help resolve issues."

### A3. Reviewing a merge request — how to review and how to phrase it

Source: `code_review.md#reviewing-a-merge-request` — `https://docs.gitlab.com/development/code_review/#reviewing-a-merge-request`

"Understand why the change is necessary (fixes a bug, improves the user experience, refactors the existing code). Then:"

- [ ] Be thorough to reduce the number of iterations.
- [ ] Communicate which ideas you feel strongly about and those you don't.
- [ ] Identify ways to simplify the code while still solving the problem.
- [ ] **Assume alternatives were considered:** "Offer alternative implementations, but assume the author already considered them. ('What do you think about using a custom validator here?')"
- [ ] Seek to understand the author's perspective.
- [ ] "Check out the branch and test the changes locally. For MRs requiring significant GDK modifications, consider requesting screenshots, videos, or domain-expert verification instead. Your testing might result in opportunities to add automated tests."
- [ ] **Ask rather than assume:** "If you don't understand a piece of code, _say so_."
- [ ] **Conventional Comments / non-blocking convention:** "Use the [Conventional Comment format](https://conventionalcomments.org#format) to convey intent. Mark non-mandatory suggestions as (`**non-blocking:**`). When only non-blocking suggestions remain, move the MR to the next stage rather than waiting."
- [ ] "Ensure there are no open dependencies. Check linked issues for blockers. If blocked by open MRs, set an MR dependency."
- [ ] "After a round of line notes, post a summary note such as 'Looks good to me' or 'Just a couple things to address.'"
- [ ] "Let the author know if changes are required following your review."
- [ ] Warning: "If the merge request is from a fork, also check the additional guidelines for community contributions."

Source: `code_review.md#participating-in-code-review`

- Be kind. "Accept that many programming decisions are opinions. Discuss trade-offs and resolve quickly."
- "Ask questions. Make suggestions, not demands."
- "Be explicit. People don't always understand your intentions online."
- "Be humble. Consider a one-on-one call for lengthy misunderstandings and post a follow-up summary."
- "Mention the person directly when a comment is addressed specifically to them."
- "Read through the entire diff before your first push. Check for unrelated changes and debug code."
- "Explain why the code exists, not just what it does."
- "Try to respond to every comment. Only resolve threads you have fully addressed."
- "Push feedback-based changes as isolated commits. Squashing commits can make it harder for your reviewer to quickly see changes."
- "Address all GitLab Duo review comments before requesting a review from human reviewers."

Source: `code_review.md#finding-the-right-balance` — approve vs request changes

- "Finding bugs is important, but good design reduces future complexity."
- "Enforce code style through automation rather than review comments."
- "For non-blocking suggestions, consider approving the MR before passing it back. This reduces time-to-merge."
- "Distinguish between doing things right and doing things right now. For example, avoid requiring major refactors in an urgent security fix."
- "Doing things well today is usually better than doing something perfectly tomorrow."

Source: `code_review.md#the-responsibility-of-the-merge-request-author` — escalation to domain experts

- "Involve domain experts, product managers, UX designers, and database specialists as appropriate. **If you are unsure whether your MR needs a domain expert review, it does.**"
- "If your MR touches multiple domains, request a review from an expert in each domain."
- "For features spanning 10 or more MRs, work with your EM or Staff Engineer to identify consistent maintainer who share the context."
- Author must add MR diff comments for: added linting rules; added libraries; links to parent classes/methods where not obvious; benchmarking results; potentially insecure code.
- "Request maintainer reviews only when tests pass. If tests are failing, explain why in a comment."

Source: `code_review.md#domain-experts` — how to find one: "View eligible approvers" in the approvals widget (CODEOWNERS), the stage/group team list, the engineering projects page, `git log <file>`, and the MRs that previously touched the files. "Due to designer capacity limits, areas not supported by a Product Designer will no longer require a UX review unless it is a community contribution."

### A4. Approval guidelines — which change needs which specialist

Source: `code_review.md#approval-guidelines` — `https://docs.gitlab.com/development/code_review/#approval-guidelines`

Context (verbatim): "For small, straightforward changes, you can skip the reviewer step and go directly to a maintainer." Examples: fixing a typo/small copy; a tiny refactor that doesn't change behavior; removing a feature flag default-enabled for more than one month; removing unused methods or classes; a well-understood logic change under five lines. "Otherwise, have a reviewer in each category the MR touches before passing to a maintainer." "After the reviewer approves, a maintainer reviews and merges. The last required approver merges." "For CODEOWNERS-required approvals, seek domain-specific approvals before generic ones."

| If your merge request includes | It must be approved by a |
|---|---|
| `~backend` changes <sup>1</sup> | Backend maintainer. |
| `~database` migrations or changes to expensive queries <sup>2</sup> | Database maintainer. Refer to the [database review guidelines](database_review.md). |
| `~workhorse` changes | Workhorse maintainer. |
| `~frontend` changes <sup>1</sup> | Frontend maintainer. |
| `~UX` user-facing changes <sup>3</sup> | Product Designer. Refer to the [design and user interface guidelines](contributing/design.md). |
| Adding a new JavaScript library <sup>1</sup> | Frontend Design System member if the library significantly increases the bundle size; a legal department member if the license hasn't been approved for use in GitLab (see [licensing.md](licensing.md)). |
| A new dependency or a file system change | Distribution team member; for RubyGems, request an [AppSec review](gemfile.md#request-an-appsec-review). |
| `~documentation` or `~UI text` changes | Technical writer based on assignments in the appropriate DevOps stage group. |
| Changes to development guidelines | Follow the [review process](development_processes.md#development-guidelines-review). |
| Changes to AI instruction files under `.ai/` | AI harness DRI. See [ai_instruction_files_review.md](ai_instruction_files_review.md). |
| End-to-end **and** non-end-to-end changes <sup>4</sup> | Software Engineer in Test. |
| Only End-to-end changes <sup>4</sup> **or** if the MR author is a Software Engineer in Test | Quality maintainer. |
| A new or updated application limit | Product manager. |
| Analytics Instrumentation (telemetry or analytics) changes | Analytics Instrumentation engineer. |
| A new service to GitLab (Puma, Sidekiq, Gitaly are examples) | Product manager. See [adding_service_component.md](adding_service_component.md). |
| Changes related to authentication | Manage:Authentication. File patterns are in the `Authentication` section of `CODEOWNERS`. |
| Changes related to custom roles or policies | Manage:Authorization Engineer. |

Footnotes (verbatim in substance):

1. "Specs other than JavaScript specs are considered `~backend` code. Haml markup is considered `~frontend` code. However, Ruby code in Haml templates is considered `~backend` code. When in doubt, request both a frontend and backend review." For Haml specifically: request **backend** review when changes include Ruby logic, method calls, variable assignments, conditionals, loops, data preparation, security checks, or server-side processing; request **frontend** review when changes affect DOM structure, CSS classes, HTML attributes, accessibility features, user interactions, responsive design, or visual presentation; request **both** when intertwined (for example, backend prepares data attributes for a Vue component such as `project_id: @project&.to_global_id`).
2. "We encourage you to seek guidance from a database maintainer if your merge request is potentially introducing expensive queries. It is most efficient to comment on the line of code in question with the SQL queries so they can give their advice."
3. "User-facing changes include both visual changes (regardless of how minor), and changes to the rendered DOM which impact how a screen reader may announce the content. Groups that do not have dedicated Product Designers do not require a Product Designer to approve feature changes, unless the changes are community contributions."
4. "End-to-end changes include all files in the `qa` directory."

Security assistance: "For security assistance, include `@gitlab-com/gl-security/appsec`." (`code_review.md#getting-your-merge-request-reviewed-approved-and-merged`)

### A5. MR description: "what and why" and testing steps

- `code_review.md#participating-in-code-review`: "Write a detailed description per the [merge request guidelines](contributing/merge_request_workflow.md#merge-request-guidelines-for-contributors)." and "Explain why the code exists, not just what it does."
- `code_review.md#for-authors-getting-changes-merged-faster`: "write clear descriptions, add screenshots and validation steps, address `dangerbot` comments, and complete the acceptance checklist." Also: "Keep MRs small. Around 200 lines is a good target." and "UI with mocked data must be behind a feature flag."
- `code_review.md#the-responsibility-of-the-merge-request-author`: "Add inline comments on lines where you made decisions or trade-offs, or where context helps the reviewer understand the code." "Ensure reviewers have access to any projects, snippets, or assets needed to validate the solution." "When assigning reviewers, comment to specify which domain each reviewer should focus on."
- `contributing/merge_request_workflow.md#description-of-changes` — `https://docs.gitlab.com/development/contributing/merge_request_workflow/#description-of-changes`:
  1. "Clear title and description explaining the relevancy of the contribution."
  2. "Description includes any steps or setup required to ensure reviewers can view the changes you've made (for example, include any information about feature flags)."
  3. Changelog entry added, if necessary.
  4. Self-compiled install steps added to `doc/install/self_compiled/_index.md` in the same MR if required.
  5. Upgrade-from-source steps added to `doc/update/upgrading_from_source.md` if required.
- `contributing/merge_request_workflow.md#ui-changes`: "Use available components from the GitLab Design System, Pajamas." "The MR must include 'Before' and 'After' screenshots if UI changes are made." "If the MR changes CSS classes, include the list of affected pages, which can be found by running `grep css-class ./app -R`."
- `contributing/merge_request_workflow.md#commit-messages-guidelines` (template): "Use the body to explain what and why vs. how"; "Explain why this change is being made"; imperative subject, max 72 chars, no emojis; "Commits that change 30 or more lines across at least 3 files should describe these changes in the commit body."
- `code_review.md#performance-reliability-and-availability` item 2 requires "information for database reviewers in the MR description" (`database_review.md#required`).
- `graphql_guide/reviewing.md#description-with-sample-query`: "Ensure that the description includes a sample query with setup instructions."

### A6. Contribution acceptance criteria and definition of done (linked from the reviewer's approve step)

Source: `contributing/merge_request_workflow.md#contribution-acceptance-criteria` — `https://docs.gitlab.com/development/contributing/merge_request_workflow/#contribution-acceptance-criteria`

1. The change is as small as possible.
2. If the MR contains more than 500 changes: explain the reason; mention a maintainer.
3. Mention any major breaking changes.
4. Include proper tests and make all tests pass (unless it contains a test exposing a bug in existing code). "Every new class should have corresponding unit tests, even if the class is exercised at a higher level, such as a feature test."
5. A few logically organized commits, or squashing enabled. "During review, push feedback-based changes as isolated commits. Do not squash until ready to merge."
6. Changes merge without problems (rebase if sole author; otherwise merge default branch in).
7. "Only one specific issue is fixed or one specific feature is implemented."
8. "Migrations should do only one thing (for example, create a table, move data to a new table, or remove an old table) to aid retrying on failure."
9. Contains functionality that other users will benefit from.
10. "Doesn't add configuration options or settings options since they complicate making and testing future changes."
11. Changes do not degrade performance: avoid repeated polling of expensive endpoints; "Check for N+1 queries via the SQL log or `QueryRecorder`"; avoid repeated file system access; use polling with ETag caching for real-time features.
12. New libraries conform to Licensing guidelines; "make the reviewer aware of the new library and explain why you need it."
13. Meets the definition of done.

Source: `contributing/merge_request_workflow.md#definition-of-done`

- Verified working in production on GitLab.com; for Self-Managed / Dedicated; supporting Geo via the self-service framework; compatible with Cells (compute scoped to a single organization; new customer-owned rows have a sharding key; no customer-owned resources outside an organization; organization data remains migratable). "If a regression occurs, we prefer you revert the change."
- `#functionality`: performance guidelines, secure coding guidelines, rate limit guidelines followed; documented in `/doc`; shell command guidelines if executing shell/reading files; observability instrumentation; migrations executed on a fresh DB before review (and again after large review changes); new validations on existing models must be backwards compatible (check existing rows via `#database` Slack, roll out behind a feature flag); consider self-managed upgrade paths and required stops.
- `#testing`: unit/integration/system tests pass on CI; peer testing recommended for high-risk changes; regressions covered with tests; Capybara tests written reliably; E2E tests if required; tested in a review app where appropriate; "Code affected by a feature flag is covered by automated tests with the feature flag enabled and disabled, or both states are tested as part of peer member testing or as part of the rollout plan"; tests for complex migrations.
- `#approval`: evaluated against the MR acceptance checklist; Infrastructure issue if default/new setting; agreed rollout plan; "Reviewed by relevant reviewers, and all concerns are addressed for Availability, Regressions, and Security. Documentation reviews should take place as soon as possible, but they should not block a merge request."; at least 1 approval plus any required by Approval guidelines; merged by a project maintainer.

### A7. GitLab-specific concerns, merging, and community MRs

Source: `code_review.md#gitlab-specific-concerns`

1. Query changes tested for GitLab.com scale (see `database_review.md`).
2. Database migrations must be reversible, performant at GitLab.com scale, and the correct migration type (`migration_style_guide.md#choose-an-appropriate-migration-type`).
3. "Sidekiq workers cannot change in a backwards-incompatible way" (`sidekiq/compatibility_across_updates.md`).
4. "Cached values may persist across releases. If you are changing the type a cached value returns … change the cache key at the same time."
5. Settings added as a last resort (`architecture.md#adding-a-new-setting-in-gitlab-rails`).
6. "File system access is not possible in a cloud-native architecture. Ensure that we support object storage for any file storage."

Source: `code_review.md#merging-a-merge-request`

- Before merging: set the milestone; confirm the MR type label; resolve Danger/code-quality warnings, or post a comment if merging with a failed job.
- "At least one maintainer must approve before merging. Authors and people who add commits cannot approve their own MR."
- Squash and merge only if the author set it or history is messy.
- Do not merge when the default branch is broken (except specific handbook cases). Start a new pipeline if the latest was created before approval and the MR has backend changes; may skip if the latest merged-results pipeline is under 16 hours old (72 for stable branches).

Source: `code_review.md#community-contributions`

- "Review all changes thoroughly for malicious code before starting a merged results pipeline."
- "Scrutinize new dependencies (e.g. `Gemfile.lock`, `yarn.lock`). They could introduce malicious packages."
- "Review links and images, especially in documentation MRs."
- "When in doubt, ask `@gitlab-com/gl-security/appsec` to review before starting any pipeline."

---

## Part C — Backend review specifics for gitlab.com

### C1. Feature flags

Source: `doc/development/feature_flags/_index.md` — `https://docs.gitlab.com/development/feature_flags/`

- [ ] **Definition YAML** exists in `config/feature_flags/<type>/` or `ee/config/feature_flags/<type>/`, created with `bin/feature-flag` (`--ee` for EE-only). Required fields: `name`, `description`, `type`, `default_enabled`, `introduced_by_url`, `milestone`, `group`. Optional: `feature_issue_url`, `rollout_issue_url`, `log_state_changes`. — `#feature-flag-definition-and-validation`, `#create-a-new-feature-flag`
- [ ] Validation rules: flag must be known (defined), not defined in both FOSS and EE, have an owner; undefined flags allowed only for `experiment`, `worker`, `undefined` types with a consistent `type:`. — `#feature-flag-definition-and-validation`
- [ ] "All newly-introduced feature flags must be **disabled by default**." — `#create-a-new-feature-flag`, `#feature-flags-in-gitlab-development`
- [ ] **Rollout issue requirement by type** (`#types-of-feature-flags`): `gitlab_com_derisk` — **Must** have a rollout issue from the Feature Flag Roll Out template; max lifespan 2 months; `default_enabled: true` must not be set. `beta` — **Must** have a rollout issue; max 6 months; may be `default_enabled: true`; must be documented. `wip` — likely no rollout issue; max 4 months; must transition type before enabling. `ops` — likely no rollout issue; unlimited but re-evaluated every 12 months; must be documented and have a runbook. `experiment` — should have a rollout issue from the Experiment Rollout template; max 6 months; must not default on.
- [ ] Type matches usage ("Most feature flags used at GitLab are of the `gitlab_com_derisk` type"). — `#types-of-feature-flags`
- [ ] "Feature flags **must** be used in the MR that introduces them" (otherwise `rspec:feature-flags` breaks master). — `#risk-of-a-broken-master-main-branch`
- [ ] Naming: snake_case, descriptive, no `_mvc`/`_alpha`/`_beta`, avoid `disable` (prefer `hide_`, `remove_`, `disallow_`). — `#naming-new-flags`
- [ ] MRs that introduce, change state of, or remove a flag carry the `~"feature flag"` label. — `#feature-flags-in-gitlab-development`
- [ ] Not a substitute for settings; not for external API consumers; not supported on Dedicated. — `#do-not-use-feature-flags-for-long-lived-settings`, `#do-not-use-feature-flags-in-external-api-consumers`
- [ ] Actor scoping: check flags with an actor (project/group/user) and avoid unnecessary queries just to obtain the actor. — `#feature-actors`
- [ ] Changelog: none for changes behind a default-off flag; required for default-on or flag removal/flip; DB migrations always get one. — `#changelog`
- [ ] Tests cover both states; flags are enabled by default in tests, so the disabled path goes in a separate `context` with `stub_feature_flags(flag: false)`. — `#feature-flags-in-tests`
- [ ] Flag removal MR: value change is the only change; legacy code removed after all mentions are gone. — `#feature-flags-in-gitlab-development`
- [ ] Optional `.patch` file alongside the YAML enables automated removal by `gitlab-housekeeper`. — `#optionally-add-a-patch-file-for-automated-removal-of-feature-flags`
- [ ] New Sidekiq workers scheduled from HTTP should be behind a flag (no canary Sidekiq). — `sidekiq/compatibility_across_updates.md#adding-new-workers`

### C2. EE / FOSS separation

Source: `doc/development/ee_features.md` — `https://docs.gitlab.com/development/ee_features/`

- [ ] "Put all Enterprise Edition (EE) inside the `ee/` top-level directory. The rest of the code must be as close to the Community Edition (CE) files as possible." "All `ee/` code must have corresponding tests in `ee/`." — top of page
- [ ] Licensed features are registered in `ee/app/models/gitlab_subscriptions/features.rb` (`PREMIUM_FEATURES`, `ULTIMATE_FEATURES`, `GLOBAL_FEATURES`) and guarded with `licensed_feature_available?(:name)` (project/group) or `License.feature_available?(:name)` (instance). — `#implement-a-new-ee-feature`, `#guard-your-ee-feature`
- [ ] EE-only classes go in `ee/app/...` without the `EE` namespace; CE extensions go in `ee/app/**/ee/...` as `::EE::Foo` modules injected with `prepend_mod` / `extend_mod` / `include_mod` (or `*_mod_with('Name')`) on the **last line** of the CE file. "Do not use methods such as `prepend`, `extend`, and `include`." — `#ee-only-features`, `#extend-ce-features-with-ee-backend-code`
- [ ] Overrides use `extend ::Gitlab::Utils::Override` and `override :method`; refactor CE into hook/template methods rather than overriding methods with guard clauses; prefer self-descriptive wrapper methods. — `#overriding-ce-methods`, `#use-self-descriptive-wrapper-methods`
- [ ] Specs: EE-only class → `ee/spec/models/foo_spec.rb`; EE extension → `ee/spec/models/ee/foo_spec.rb` with `RSpec.describe User`; enable features with `stub_licensed_features(...)`. — `#testing-ee-only-backend-features`, `#testing-ee-features-based-on-ce-features`
- [ ] GraphQL: EE mutations/resolvers/types in `ee/app/graphql/...`; overrides in `ee/app/graphql/ee/...` inside a `prepended do` block. — `#code-in-appgraphql`
- [ ] Views use `render_if_exists` / `render_ce`; routes, controllers, initializers, `lib/`, `lib/api/` each have their own patterns. — `#code-in-appviews`, `#code-in-configroutes`, `#code-in-appcontrollers`, `#code-in-lib`, `#code-in-libapi`
- [ ] SaaS-only: `Gitlab::Saas.feature_available?(:name)` with the feature added to `FEATURES` in `ee/lib/gitlab/saas.rb`; "`Gitlab::Saas.feature_available?` must not appear in CE." — `#saas-only-feature`, `#do-not-use-saas-only-features-for-functionality-in-ce`
- [ ] Dedicated: `Gitlab::Dedicated.feature_available?(:name)`; do not call `Gitlab::CurrentSettings.gitlab_dedicated_instance?` in app code (RuboCop `Gitlab/AvoidGitlabDedicatedInstanceChecks`), migrations excepted. — `#why-dedicated-code-must-be-in-ee`, `#exceptions-for-database-migrations`
- [ ] Consider running the pipeline in a FOSS context. — `#run-ci-pipelines-in-a-foss-context`; `code_review.md#quality` item 8
- [ ] Frontend EE files under `ee/app/assets/javascripts`, imported via `ee/` or `ee_else_ce/`. — `#separation-of-ee-code-in-the-frontend`

### C3. Sidekiq workers

Sources: `doc/development/sidekiq/_index.md`, `idempotent_jobs.md`, `worker_attributes.md`, `compatibility_across_updates.md` — `https://docs.gitlab.com/development/sidekiq/`

- [ ] `include ApplicationWorker`, not `Sidekiq::Worker`. — `_index.md#applicationworker`
- [ ] Cells: "All Sidekiq jobs should be scoped to a single organization"; cross-organization jobs only if both a recurring cron job **and** idempotent. — `_index.md#cells-compatibility`
- [ ] Sharding: Sidekiq API calls go through `Sidekiq::Client.via(pool)` using `Gitlab::SidekiqSharding::Router.get_shard_instance`; `allow_unrouted_sidekiq_calls` only with a justifying comment for non-GitLab.com code. — `_index.md#sharding`
- [ ] **Idempotency**: worker `idempotent!` (a cop fails otherwise); can "safely run multiple times with the same arguments"; spec uses `it_behaves_like 'an idempotent worker'` with no mocks that hide side effects; deduplication strategy (`until_executing` / `until_executed`), `including_scheduled:`, and `ttl:` set deliberately. — `idempotent_jobs.md#declaring-a-worker-as-idempotent`, `#ensuring-a-worker-is-idempotent`, `#deduplication`, `#setting-the-deduplication-time-to-live-ttl`
- [ ] **`data_consistency`** explicitly set (RuboCop-enforced): `:always` "Strongly discouraged"; `:sticky` "the preferred option"; `:delayed` for jobs where delay doesn't matter (cache expiry, webhooks) and **not** for jobs with retries disabled such as cron jobs. Optional `feature_flag:` (percentage-of-time only) and `overrides:` per database. — `worker_attributes.md#job-data-consistency-strategies`, `#trading-immediacy-for-reduced-primary-load`, `#feature_flag-property`
- [ ] `feature_category` defined ("All Sidekiq workers must define a known feature category"). — `worker_attributes.md#feature-category`
- [ ] `urgency` appropriate (`:high` 10s/10s, `:low` default 1min/5min, `:throttled`); external dependencies declared (`worker_has_external_dependencies!`); CPU/memory-bound declared where applicable. — `worker_attributes.md#job-urgency`, `#jobs-with-external-dependencies`, `#cpu-bound-and-memory-bound-workers`
- [ ] Retries: guard against state changes (`find_by_id` + `return unless`), let exceptions raise for retry, `sidekiq_retries_exhausted` for permanent-failure handling. — `_index.md#retries`, `_index.md#failure-handling`
- [ ] **Backwards compatibility**: "Jobs need to be backward and forward compatible between consecutive versions"; adding/removing arguments follows the deprecate-then-remove or multi-step release process; use `version N` and handle older job shapes; worker/queue renames and removals span M, M+1, M+2. — `compatibility_across_updates.md#changing-the-arguments-for-a-worker`, `_index.md#versioning`, `compatibility_across_updates.md#removing-worker-classes`
- [ ] Parameters small, simple, native JSON types (string keys); >100 KB compressed, >5 MB raises `ExceedLimitError`; consistent parameter ordering. — `_index.md#job-parameters`, `#job-size`, `#parameter-ordering`
- [ ] Concurrency limits, deferral, and pause control considered for high-volume workers. — `_index.md#concurrency-limit`, `#deferring-sidekiq-workers`, `worker_attributes.md#job-pause-control`
- [ ] "Sidekiq workers cannot change in a backwards-incompatible way." — `code_review.md#gitlab-specific-concerns`

### C4. REST API (Grape)

Source: `doc/development/api_styleguide.md` — `https://docs.gitlab.com/development/api_styleguide/`

- [ ] REST and GraphQL share implementations (services). — `#graphql-and-rest-apis`
- [ ] No instance variables in endpoints. — `#instance-variables`
- [ ] Entities: don't add fields to high-impact/shared entities (`UserBasic` etc.); create domain-scoped entities; allowlist updates. — `#high-impact-entities-and-feature-bounded-entities`
- [ ] `desc` blocks with `detail`, `success`, `failure`, `tags`; lifecycle via `route_setting`; deprecation via `deprecated true` + `detail` note (not `route_setting :lifecycle`). — `#methods-and-parameters-description`, `#marking-endpoints-as-deprecated`, `#marking-endpoint-lifecycle`
- [ ] **No breaking changes to v4** except experiment/beta elements. Breaking: removing/renaming fields, args, enum values; removing endpoints; new redirects; content-type change; field type change; new **required** argument; auth/header requirement changes; any status code change other than `500`. — `#breaking-changes`, `#what-is-a-breaking-change`, `#what-is-not-a-breaking-change`
- [ ] Use `declared(params)`; constrain string params; custom validators. — `#declared-parameters`, `#constrain-string-parameters`, `#custom-validators`
- [ ] **N+1**: eager load via `with_api_entity_associations`; "When an API endpoint returns collections, always add a test to verify that the API endpoint does not have an N+1 problem" using `ActiveRecord::QueryRecorder` and `not_to exceed_query_limit(control)`. — `#avoiding-n1-problems`, `#verifying-with-tests`
- [ ] Response schema fixtures under `spec/fixtures/api/schemas`; changelog entry. — `#testing`, `#include-a-changelog-entry`

### C5. GraphQL backend

Sources: `doc/development/graphql_guide/reviewing.md` — `https://docs.gitlab.com/development/graphql_guide/reviewing/`; `doc/development/api_graphql_styleguide.md`; `graphql_guide/authorization.md`

Reviewer checklist from `reviewing.md` (reviewed "for: breaking changes, authorization, performance"; ping `@gitlab-org/graphql-experts`):

- [ ] Description includes a sample query with setup instructions; run it in GraphiQL. — `#description-with-sample-query`
- [ ] No breaking changes unless after a full deprecation cycle (experiments exempt). — `#no-breaking-changes-unless-after-full-deprecation-cycle`
- [ ] Multiversion compatibility: "frontend and backend code for the same GraphQL feature can't be shipped in the same release." — `#multiversion-compatibility`
- [ ] Technical writer review for generated API docs; changelog for public non-experiment changes. — `#technical-writing-review`, `#changelog`
- [ ] Use the framework: don't instantiate resolvers manually; `ready?` for argument logic; `prepare` for validation. — `#use-the-framework`
- [ ] **Authorization**: "Ensure proper authorization is followed and that `authorize :some_ability` is tested in the specs." — `#authorization`
- [ ] **Performance**: checked for N+1s, used optimizations, used laziness appropriately. — `#performance`
- [ ] Frontend fragment N+1 blockers (see B4 in frontend.md). — `#frontend-graphql-fragment-changes`
- [ ] Appropriate types (`TimeType`, Global IDs) and complexity. — `#use-appropriate-types`, `#appropriate-complexity`
- [ ] Testing: request (integration) specs, not resolver unit specs; "Every GraphQL change MR should ideally have changes to API specs." — `#testing`

Supporting rules from `api_graphql_styleguide.md`:

- [ ] Breaking changes list: removing/renaming fields, args, enum values, mutations; changing argument type/name; scalar serialization changes; raising complexity; `null: false` → `null: true`; optional → required argument; changing max page size; lowering global limits. — `#breaking-changes`
- [ ] Deprecation: create a deprecation issue (`~GraphQL`, `~deprecation`), mark with `deprecated: { reason:, milestone: }`, keep the original description, reason names the replacement. — `#deprecating-schema-items`, `#deprecation-reason-style-guide`
- [ ] Feature-flagged schema items: mark as `experiment`; description must state it's toggled by a flag, name the flag, and describe the disabled behavior. — `#feature-flags`, `#descriptions-for-feature-flagged-items`
- [ ] Global IDs only, "never database primary key IDs." — `#global-ids`
- [ ] N+1 tools: look-ahead, BatchLoader / `BatchModelLoader`, `before_connection_authorization`, max field call count; detect via `development.log`, performance bar, request spec. — `#optimizations`, `#how-to-see-n1-problems-in-development`
- [ ] Mutations: `authorize :ability` + `authorize!`/`authorized_find!`; raise `ResourceNotAvailable` for not-found-or-unauthorized; user-input validation errors go to the `errors` payload; all mutation payload fields `null: true`; clients always request `errors`. — `#authorizing-resources`, `#errors-in-mutations`
- [ ] Tests: "Only integration tests can verify fully that a query or mutation executes"; unit tests only for static schema shape. — `#testing`

From `graphql_guide/authorization.md`:

- [ ] Authorization on types, resolvers (`authorizes_object!`), and fields via `DeclarativePolicy`; single values resolve to `null`, collections are redacted after pagination. Best practice: load only what the user may see with finders first. — `#top`, `#type-authorization`, `#resolver-authorization`, `#field-authorization`
- [ ] **"Do not use `loads:` in argument definitions"** — it leaks existence vs permission; accept the Global ID and use `authorized_find!` (RuboCop `Graphql/ForbiddenLoadsArgument`). — `#do-not-use-loads-in-argument-definitions`

### C6. Secure coding guidelines (headings only)

Source: `doc/development/secure_coding_guidelines/_index.md` — `https://docs.gitlab.com/development/secure_coding_guidelines/` (the single-file path in the task does not exist; this directory does)

`_index.md` top-level sections: SAST coverage; Process for creating new guidelines and accompanying rules; Permissions; CI/CD development; Denial of Service (ReDoS) / Catastrophic Backtracking; JSON Parsing (`Gitlab::Json.parse`, deprecated `safe_parse`); JSON Web Tokens (JWT); Server Side Request Forgery (SSRF); XSS guidelines (including "XSS mitigation and prevention in JavaScript and Vue", "Content Security Policy"); Path Traversal guidelines; General recommendations (TLS minimum version, ciphers); GitLab Internal Authorization; Time of check to time of use bugs; Handling credentials (at rest, in transit, token prefixes); Artificial Intelligence (AI) features (unauthorized model endpoint access, prompt injection, unsanitized responses, training, insecure design); OWASP Top 10 for LLM Applications; Local Storage; Logging (what to log, what not to capture, protecting log files); Paid tiers for vulnerability mitigation; Who to contact if you have questions.

`ruby.md` sections: Regular Expressions guidelines (anchors / multi-line); ReDoS; SSRF; XSS (Rails); XML external entities; Path Traversal; OS command injection; Working with archive files (`SafeZip`, Zip Slip, symlink attacks); URL Spoofing (`external_redirect_path`); Email and notifications; Request Parameter Typing; Guidelines when defining missing methods with metaprogramming; Serialization.

`go.md` exists for Go-specific guidance (not read).

### C7. Database (pointer only; not read in depth)

Source: `doc/development/database_review.md` — `https://docs.gitlab.com/development/database_review/`. Sections: General process; Required (Migrations, Queries); Roles and process; How to prepare the merge request for a database review (migrations, data migrations, raw SQL, query plans, foreign keys, tables, removals, bulk updates); How to review for database (basic migration requirements, style/standards, large table restrictions, timing/performance, background migrations, new table/column reviews, query performance analysis). The acceptance checklist requires "information for database reviewers in the MR description" (`database_review.md#required`), and `code_review.md#gitlab-specific-concerns` requires migrations to be reversible, performant at GitLab.com scale, and of the correct type.

---

## Notes on the sources

**Source repo:** `/Users/surajtripathi/repo/gitlab-development-kit/gitlab` (the path given in the task, `repo/gitlabdevelopmentkit/gitlab`, does not exist; the coordinator corrected it mid-task). Docs read at commit `718b5cb265bf3e24bd650275799257c667023561` (2026-08-31). Nothing was modified.

**File-existence notes (things the task asked for that differ on disk):**

- `doc/development/fe_guide/index.md` does not exist; the page is `doc/development/fe_guide/_index.md`.
- `doc/development/secure_coding_guidelines.md` does not exist as a file. It is a directory: `doc/development/secure_coding_guidelines/{_index.md,ruby.md,go.md}`.
- There is **no dedicated frontend review page** in `doc/development/fe_guide/`. No filename contains "review" and the only headings matching "review" are unrelated ("Color scheme preview thumbnails", "Step 4: Review" in `getting_started.md`, "Preview layouts"). The closest review-specific pages are `doc/development/graphql_guide/reviewing.md` (which has a "Frontend GraphQL fragment changes" section) and `code_review.md` footnote 1 on Haml/frontend routing.
- The "acceptance checklist" with Quality / Performance / Observability / Documentation / Security / Deployment / Compliance lives in `code_review.md#acceptance-checklist`. A **separate** list called "Contribution acceptance criteria" lives in `contributing/merge_request_workflow.md#contribution-acceptance-criteria`; both are reproduced above.
- The "Review-response SLO" is only linked from `code_review.md` to the handbook; the repo docs do not state a numeric turnaround value.

**Key findings for the caller:**

1. The single most useful reviewer-facing artifact is `code_review.md#acceptance-checklist`; it is reproduced verbatim in A1. Its "approve" trigger (`#the-responsibility-of-the-reviewer`) points at a **different** list, `merge_request_workflow.md#contribution-acceptance-criteria`, reproduced in A6.
2. There is no frontend-specific review page; Part B (frontend.md) is synthesized from the fe_guide style/architecture/testing pages plus `graphql_guide/reviewing.md#frontend-graphql-fragment-changes`, which is the only doc with explicit "Blocker" language for frontend changes.
3. Hard blockers explicitly stated in the docs: `@feature_category` comment on every `.graphql` file (ESLint); backend batch-loading and `QueryRecorder` coverage for new nested GraphQL fields; feature flag must be used in the MR that introduces it; `data_consistency` and `idempotent!`/`feature_category` on workers (RuboCop); no `loads:` in GraphQL arguments (RuboCop); Storybook axe violations block merges for components with stories.
4. The review-response SLO number is not in the repo docs — only a handbook link.

---

# Applying this checklist in the skill

## Applicability by repo

| Area | gitlab-org/gitlab | customers-gitlab-com |
|---|---|---|
| A1 acceptance checklist, A3 how to review, A5 description requirements | as written | as written; the MR template links the same checklist |
| A4 approval guidelines (which specialist) | as written | roles come from the Danger roulette table; `~database` needs a DB reviewer, frontend/backend maintainers per the handbook `#customers-app` page |
| A6 contribution acceptance criteria, definition of done | as written | as written except Geo/Cells/Self-Managed items, which are `n/a` |
| C1 feature flags | Flipper-style `Feature.enabled?`, YAML definition, rollout issue by type | Unleash `Unleash.enabled?`; flag lives on the project's Feature Flags page; MR must list it under "Feature flags to enable"; ask for the rollout / removal issue |
| C2 EE / FOSS | as written | `n/a` |
| C3 Sidekiq | as written | `idempotent!`, `feature_category`, retries and argument compatibility apply; `data_consistency`, sharding and Cells items are `n/a`; a job without `feature_category` is blocking per the repo's Duo instructions |
| C4 REST (Grape) | as written | internal API under `app/controllers/api/`; the internal-API doc `doc/architecture/cells/api_requests.md` governs requests to GitLab; breaking-change reasoning applies to anything GitLab.com calls |
| C5 GraphQL backend | as written | `graphql-ruby` schema in `app/graphql/`; authorization via CanCanCan abilities (`authorize!`), errors-as-data convention applies, batch loading for N+1 |
| C6 secure coding | as written | as written; no scanner runs in customers-dot, so the items are checked by reading (`.agents/skills/rails/references/security.md`) |

For customers-dot Ruby, the repo's own review reference is authoritative on layering and
conventions: `.agents/skills/rails/references/review.md` (Controller → Interaction → Service →
Model, dry-monads not `ServiceResponse`, `on_delete` on every FK, anemic-model and code-smell
list) and `.agents/skills/rspec/SKILL.md` for specs. Walk that file's checklist as well and
record verdicts in the same Phase 4 table.
