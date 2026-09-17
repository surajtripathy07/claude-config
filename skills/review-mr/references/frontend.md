---
These reference files distill GitLab's public developer documentation (docs.gitlab.com) into a portable review checklist — freely readable, sourced, and not specific to any one project's private code. The distillation is pinned at docs commit `<sha>` — refresh this file when the docs change and record the new commit here. Source of truth is those docs, not this file: when an item fires during a review, open the doc it cites and read that section in full before recording a verdict. Where the project under review differs, the profile says so — see "Applicability" at the end.
---

# Frontend review checklist (distilled from public developer docs)

**Source pointer convention.** `doc/development/<path>.md#<anchor>` maps to `https://docs.gitlab.com/development/<path>/#<anchor>`. Files named `_index.md` map to the directory URL (for example `doc/development/fe_guide/_index.md` → `https://docs.gitlab.com/development/fe_guide/`).

**File-existence notes (frontend):**

- `doc/development/fe_guide/index.md` does not exist; the page is `doc/development/fe_guide/_index.md`.
- There is **no dedicated frontend review page** in `doc/development/fe_guide/`. No filename contains "review" and the only headings matching "review" are unrelated ("Color scheme preview thumbnails", "Step 4: Review" in `getting_started.md`, "Preview layouts"). The closest review-specific pages are `doc/development/graphql_guide/reviewing.md` (which has a "Frontend GraphQL fragment changes" section) and `code_review.md` footnote 1 on Haml/frontend routing.

## Part B — Frontend review

Pages read: `fe_guide/_index.md`, `fe_guide/vue.md`, `fe_guide/style/vue.md`, `fe_guide/style/javascript.md`, `fe_guide/graphql.md`, `fe_guide/state_management.md`, `fe_guide/performance.md`, `fe_guide/accessibility/{_index,best_practices,automated_testing}.md`, `i18n/externalization.md`, `testing_guide/frontend_testing.md`, `feature_flags/_index.md#frontend`, `graphql_guide/reviewing.md#frontend-graphql-fragment-changes`.

### B1. Architecture and component structure

- [ ] Vue is justified: "when we need to maintain application state and synchronize the rendered page with it"; otherwise Haml may suffice. Flags: complex conditionals updated on interaction; shared state across elements; complex logic expected later. — `fe_guide/vue.md#when-to-add-a-vue-application`, `#what-are-some-flags-signaling-that-you-might-need-a-vue-application`
- [ ] No new Vue app added to a page that already has one unless "absolutely impossible to extend an existing application"; if added anyway, "make sure it shares local state with existing applications." — `fe_guide/vue.md#avoid-multiple-vue-applications-on-the-page`
- [ ] Feature folder layout: `components/`, `graphql/`, `utils/`, optional `router/`, `constants.js`, `index.js`; page entry under `app/assets/javascripts/pages/<controller>/<action>/index.js`. Package boundaries between top-level folders are enforced in CI. — `fe_guide/_index.md#high-level-overview`, `fe_guide/package_boundaries.md`
- [ ] "Use `.vue` for Vue templates. Do not use `%template` in HAML." — `fe_guide/style/vue.md#basic-rules`
- [ ] Data passed into the Vue app is explicit: no spread of datasets into `provide`/`props` ("keep our codebase explicit, discoverable, and searchable"); parse non-scalar values at instantiation (for example `parseBoolean`). — `fe_guide/style/vue.md#basic-rules`
- [ ] Data from HAML arrives via `data-*` attributes read once at mount time (data attributes are strings; cast them); `initSimpleApp` and `data-provide` JSON are acceptable; the mount `id` "is unique across the codebase." — `fe_guide/vue.md#providing-data-from-haml-to-javascript`, `#the-initsimpleapp-helper`, `#props`
- [ ] `gl` object read only at the entry point and passed as props. — `fe_guide/vue.md#accessing-the-gl-object`
- [ ] "Every Vue component should have a `name` property. Use PascalCase derived from the filename." Generic filenames get directory context (`AdminUsersApp`); where a licensed-tier component shares a name with a base one, the project's convention distinguishes them by suffix. — `fe_guide/style/vue.md#component-name-property`
- [ ] Kebab-case component names in templates (`<my-component />`). — `fe_guide/style/vue.md#component-usage-within-templates`
- [ ] No `<style>` tags in Vue components; use Tailwind utility classes or page-specific CSS. — `fe_guide/style/vue.md#style-tags`
- [ ] No JavaScript classes in `data()`; "Do not add new JavaScript class implementations"; move business logic to separate files. — `fe_guide/vue.md#mixing-vue-and-javascript-classes-in-the-data-function`
- [ ] No mixing Vue and jQuery beyond listening to existing jQuery events. — `fe_guide/vue.md#mixing-vue-and-jquery`
- [ ] Composition API: use `<script>` with `setup()` (not `<script setup>`); one API style per component; composables prefixed `use`/`use_`; composables minimize lifecycle hooks and clean up what they register; no `getCurrentInstance` escape hatch. — `fe_guide/vue.md#prefer-script-over-script-setup`, `#aim-to-have-one-api-style-per-component`, `#composables`, `#avoid-lifecycle-pitfalls`, `#avoid-escape-hatches`
- [ ] Vue 3 migration debt avoided: no new filters, event buses, functional templates, or `slot` attributes. — `fe_guide/vue.md#vue-2---vue-3-migration`
- [ ] Reusable components go in `vue_shared/components`; a table is a good component, a one-off cell is not. — `fe_guide/vue.md#a-folder-for-components`
- [ ] Prefer the project's design-system components over new one-off markup. — `contributing/merge_request_workflow.md#ui-changes`

### B2. Props, emits, and data flow

- [ ] "Prefer semantic props that describe intent over generic pass-through CSS class props" (for example `truncate-username` rather than `username-css-classes`). — `fe_guide/style/vue.md#component-props`
- [ ] "Avoid using `v-bind="$attrs"` unless absolutely necessary … always prefer using `props` and explicit data flow." Reasons: loss of component contract, hard to debug, Vue 3 `$attrs` includes listeners. — `fe_guide/vue.md#v-bind-limitations`
- [ ] One data flow, one data entry (Pinia or Apollo). — `fe_guide/vue.md#vue-architecture`
- [ ] Feature flags and abilities reach descendants via `provide`/`inject` (`glFeatures`, `glAbilities` via mixins), not prop drilling. — `fe_guide/vue.md#accessing-feature-flags`, `#accessing-abilities`
- [ ] Props validation is testable with `assertProps`. — `fe_guide/style/vue.md#testing-props-validation`
- [ ] Note: the fe_guide does not mandate a specific "emit typing" convention beyond testing `emitted()`; see B8.

### B3. State management choice (Apollo vs Pinia vs local)

Source: `fe_guide/state_management.md` — `https://docs.gitlab.com/development/fe_guide/state_management/`

- [ ] "You should prefer using the standard Vue data flow in your application first: components define local state and pass it down through props and change it through events." Reach for a store only when state is shared across non-descendant components. "If you're still uncertain, prefer using Apollo before Pinia." — `#do-i-need-to-have-state-management`
- [ ] Pick Apollo when: "You rely on the GraphQL API" or need Apollo features (parametrized cache/invalidation, polling, stale-while-revalidate, subscriptions). — `#pick-apollo-when`
- [ ] Pick Pinia when: a significant percentage of state is client-side; migrating from Vuex is high priority; the app doesn't rely primarily on GraphQL. — `#pick-pinia-when-you-have-any-of-these`
- [ ] Where the project has deprecated its store library, **no new stores should be created** in it; new state goes to the current approach. — `#top`; also `fe_guide/_index.md#introduction`
- [ ] Combining Pinia and Apollo "is not recommended". If unavoidable: "**Never use Apollo Client in Pinia stores**"; do not sync data between them; one source of truth per request. — `#combining-pinia-and-apollo`
- [ ] "Do not add new Pinia stores on top of the existing Vuex store, migrate first." — `#vuex-used-alongside-apollo`
- [ ] Goal: "stop using Apollo and Vuex together." — `fe_guide/_index.md#goals`

### B4. GraphQL client conventions

Source: `fe_guide/graphql.md` — `https://docs.gitlab.com/development/fe_guide/graphql/`

- [ ] GraphQL is "the first choice" for API calls; REST only for simple Haml pages or legacy areas. — `fe_guide/_index.md#introduction`
- [ ] Uses the default client from `~/lib/graphql` (`createDefaultClient`), created where the app mounts. — `#apollo-client`, `#usage-in-vue`
- [ ] File naming: `*.query.graphql`, `*.mutation.graphql`, `*.fragment.graphql`; a project that proxies another service's schema may add its own suffix convention (the profile records it). — `#graphql-queries`
- [ ] **Feature category comment required** on every query/mutation/subscription file: `# @feature_category: <category>` (enforced by ESLint `local-rules/graphql-require-feature-category`; value must be in `config/feature_categories.yml`). Optional `# @urgency: high|medium|default|low`. — `#feature-category-requirement`, `#urgency-tag-optional`
- [ ] Fragments used for readability/reuse, imported with `#import`. — `#fragments`
- [ ] **Global `id` queried for every type that has an `id` in the schema** ("It is required"); use `getIdFromGraphQLId` when the PK is needed. — `#global-ids`
- [ ] Cache updates are immutable; use Immer `produce`; name updated cache `data`, original `sourceData`. — `#immutability-and-cache-updates`
- [ ] Mutation `update` hook only when adding/removing items from the cache; updating an existing item with `id` in the payload updates automatically. — `#when-to-use-and-not-use-update-hook-in-mutations`
- [ ] Types without `id` that produce "Cache data may be lost" warnings need a `merge` type policy. — `#multiple-client-queries-for-the-same-object`
- [ ] **`@client`**: preferred way to ship frontend ahead of backend; skipped by the `graphql-verify` CI job; "Make sure to track the removal of the directive in a follow-up issue." Adding files to `config/known_invalid_graphql_queries.yml` disables validation for the whole file and should be short-lived. — `#using-the-client-directive`, `#adding-an-exception-to-the-list-of-known-failures`
- [ ] **Feature-flagged queries**: prefer `@include(if: $flag)`/`@skip` driven by however flag state reaches the frontend; the guarded field must exist in the schema, and the backend resolver should return `null` under the same flag. Duplicated query versions "should be avoided" except when new entities aren't in the schema or are flagged at the schema level. — `#feature-flagged-queries`, `#the-include-directive`, `#avoiding-multiple-query-versions`
- [ ] **Pagination**: Relay cursor pagination; use `page_info.fragment.graphql`; `fetchMore` for user-driven pagination; a non-smart recursive query when all data is needed up front. — `#working-with-pagination`, `#using-fetchmore-method-in-components`, `#using-a-recursive-query-in-components`
- [ ] Batching via `context.batchKey` when the same query fires repeatedly from one component. — `#batching-similar-queries`
- [ ] **Polling**: ETag-based caching preferred over plain client polling; the project's own
  resource-ETag and correlation headers carry it. — `#polling-and-performance`
- [ ] **Error handling**: handle **both** top-level errors (non-recoverable; message defined client-side) and errors-as-data (`errors` field requested on every mutation; may be shown to the user). — `#handling-errors`, `#top-level-errors`, `#errors-as-data`
- [ ] Manually triggered queries use `skip()` or `addSmartQuery`. — `#manually-triggering-queries`
- [ ] Subscriptions: thin payloads with refetch, visibility guards, batched fetches, polling safety net, no accumulation. — `#best-practices-for-subscriptions`
- [ ] **N+1 risk in fragment changes** (reviewer-directed, from `graphql_guide/reviewing.md#frontend-graphql-fragment-changes`): trace query depth when a fragment adds a nested association; watch list-of-lists; **Blocker:** backend must batch-load the new field (`BatchLoader::GraphQL` or `LooksAhead` `preloads`/`unconditional_includes`); **Blocker:** matching request spec must have `not_to exceed_query_limit(N)` with a multi-record fixture.

### B5. Accessibility

Source: `fe_guide/accessibility/best_practices.md` — `https://docs.gitlab.com/development/fe_guide/accessibility/best_practices/`; target is WCAG 2.1 AA (`accessibility/_index.md`).

- [ ] "no ARIA is better than bad ARIA" — prefer semantic HTML; "when in doubt don't use `aria-*`, `role`, and `tabindex`." — `#quick-summary`
- [ ] Quick checklist (`#quick-checklist`): text/textarea/select/checkbox/radio/file/toggle inputs have accessible names; buttons, links, images have descriptive accessible names; non-decorative icons have `aria-label`; clickable icons are buttons (`<gl-button icon="close" />`, not `<gl-icon />`); icon-only buttons have `aria-label`; interactive elements are Tab-reachable with a visible focus state; tooltip hosts are focusable; no unnecessary `role`/`tabindex`/`aria-*`; `div`/`span` replaced by semantic elements where possible.
- [ ] Document outline: one `h1`, no skipped levels, correct nesting. — `#provide-a-good-document-outline`
- [ ] Accessible names: every input has a `label`; buttons/links have visible text or `aria-label`; images have `alt` (≈150 chars max); `fieldset` → `legend`, `figure` → `figcaption`, `table` → `caption` as first child; checkbox/radio groups in `fieldset`+`legend`; `gl-sr-only` for visually hidden labels. `GlFormGroup` with only `label` renders `fieldset`/`legend`; with `label-for` renders a `label`. — `#provide-accessible-names-for-screen-readers`, `#form-inputs-with-accessible-names`
- [ ] Button/link text understandable in isolation ("Submit review", not "Submit"). — `#buttons-and-links-with-descriptive-accessible-names`
- [ ] Avoid `role`; use the semantic element table (`<div role="button">` → `<button>`, etc.). — `#role`
- [ ] Keyboard: interactive elements receive focus and show a focus state; `:hover` styles get `:focus` too; removed `outline` replaced (for example `box-shadow`). — `#support-keyboard-only-use`
- [ ] `tabindex`: prefer none; never `tabindex="0"` to make a `div` interactive, on already-interactive elements, or on text for screen readers; never positive `tabindex`. — `#tabindex` and sub-sections
- [ ] Icons: decorative `GlIcon` needs no `aria-hidden` (already hidden); informative icons need `aria-label`; clickable icons are `GlButton`s. — `#icons`
- [ ] Hiding: `.gl-sr-only` (sighted), `aria-hidden="true"` (SR), `display:none`/`hidden` (both); decorative `img` uses `alt=""`; inline SVG uses `role="img"` + `alt=""`. — `#hiding-elements`
- [ ] ARIA only for patterns with no semantic equivalent (dialogs, tabs, custom dropdowns), with WCAG testing. — `#when-to-use-aria`
- [ ] Automated coverage: Storybook axe-playwright tests run in CI on Vue/JS changes and "block merges when they find violations" but only for components with up-to-date stories; feature tests with `axe-core-gem` for full journeys; new components should have stories covering all states plus manual keyboard and screen-reader testing. — `accessibility/_index.md#storybook-component-testing`, `#new-components`, `accessibility/automated_testing.md#our-testing-approach`
- [ ] Test selectors: prefer `findByRole` ("helps enforce accessibility best practices") over `data-testid`; `data-testid` in kebab-case as fallback. — `testing_guide/frontend_testing.md#how-to-query-dom-elements`
- [ ] Contrast: not covered in the guide text read; the docs defer to the design system's accessibility guidance and to axe tooling.

### B6. Internationalization

Source: `i18n/externalization.md` — `https://docs.gitlab.com/development/i18n/externalization/`

- [ ] Helpers: `__()`, `s__()` (namespaced), `n__()` (plural), `sprintf`; available in Vue templates via the `translate` mixin; import from `~/locale` in component JS. — `#javascript-files`, `#vue-files`
- [ ] **String literals only**: "make sure to always pass string literals to the helpers." Bad: `__(LABEL)`, `` __(`Step: ${count}`) ``, `s__(getLabel())`, `n__(LABEL_SINGULAR, LABEL_PLURAL, n)`. — `#always-pass-string-literals-to-the-translation-helpers`
- [ ] **No sentence splitting / concatenation**: "Never split a sentence"; use `sprintf`/`GlSprintf` with placeholders; links use `%{linkStart}`/`%{linkEnd}`. — `#splitting-sentences`, `#avoid-splitting-sentences-when-adding-links`
- [ ] Placeholders camelCase in JS (`%{createdAt}`); `GlSprintf` when the string contains child components, HTML, or unescaped values. — `#interpolation`
- [ ] Namespaces are PascalCase, granular (`MergeRequestReviewActions|Approve` over `MergeRequest|Approve`); "always add a namespace to UI text in English." — `#namespaces`
- [ ] Vue SFCs: put the translation call **inline in `<template>`**; use `$options.i18n` only for shared template+JS usage, strings needing processing (`sanitize`), lookup maps keyed at runtime, or module-shared strings. Applies to new and changed code only. — `#vue-single-file-components`; mirrored in `fe_guide/style/vue.md#translated-strings`
- [ ] Avoid inserting nouns as variables (gender/case/word-order); prefer separate strings or topic-comment structure. — `#using-variables-to-insert-text-dynamically`
- [ ] Minimize edits to existing strings (translations are lost). — `#minimize-translation-updates`
- [ ] Tests assert literal strings, not imported constants. — `testing_guide/frontend_testing.md#dont-use-imported-values-in-assertions`

### B7. Feature flags in the frontend

- [ ] Backend pushes the flag with `push_frontend_feature_flag(:flag, actor)` (scoped per project/user); "When using a feature flag for UI elements, make sure to also use a feature flag for the underlying backend code." — `feature_flags/_index.md#frontend`
- [ ] The frontend reads flag state through whatever channel the profile names (a page-bootstrap global, a GraphQL field, a prop), with the casing that channel requires. Flags without a definition file must declare their type. — `feature_flags/_index.md#frontend`
- [ ] In Vue, flag state is read through the project's own mixin or injection rather than a
  global lookup at the call site, and tests provide it the same way. — `fe_guide/vue.md#accessing-feature-flags`
- [ ] GraphQL queries gated with `@include(if:)` from the flag state; see B4. — `fe_guide/graphql.md#the-include-directive`
- [ ] "UI with mocked data must be behind a feature flag." — `code_review.md#for-authors-getting-changes-merged-faster`
- [ ] Rails feature specs can assert `have_pushed_frontend_feature_flags(...)`. — `feature_flags/_index.md#have_pushed_frontend_feature_flags`

### B8. Testing expectations (Jest + Vue Test Utils)

Source: `testing_guide/frontend_testing.md` — `https://docs.gitlab.com/development/testing_guide/frontend_testing/`; `fe_guide/style/vue.md#vue-testing`; `fe_guide/vue.md#testing-vue-components`

- [ ] Component specs live in the project's frontend spec tree (and, if it separates a licensed code path, in the matching tree on that side); named `${componentName}_spec.js`. — `#jest`, `#naming-unitcomponent-tests`
- [ ] **Don't test the library**: testing a computed that returns `.length` tests Vue; "if you are checking a `wrapper.vm` property, you should probably stop and rethink the test to check the rendered template instead." — `#dont-test-the-library`
- [ ] **Don't test your mock**; mocks support the test, not the target. — `#dont-test-your-mock`
- [ ] **Follow the user**: trigger via rendered markup and assert markup changes rather than calling methods; unit-test in isolation only for complex logic. — `#follow-the-user`
- [ ] Goal is to test render output: "our goal is to test the output of the render function." — `fe_guide/vue.md#testing-vue-components`
- [ ] **Mounting**: mutable `wrapper`, `createComponent` factory (object argument, optional `mountFn` to switch `mount`/`shallowMount`), `shallowMountExtended`/`mountExtended` for `findByTestId`/`findByRole`/`findByText`; `shallowMount` doesn't stub async children — use `stubs` and ensure the child has `name`. — `fe_guide/style/vue.md#mounting-a-component`, `#the-createcomponent-factory`, `#createcomponent-best-practices`, `#async-child-components`, `testing_guide/frontend_testing.md#shallowmountextended-and-mountextended`
- [ ] "Avoid using `data`, `methods`, or any other mounting option that extends component internals." Avoid `setProps` (except to test reactivity/watchers) and `setData`; use `propsData` and trigger real interactions. — `fe_guide/style/vue.md#createcomponent-best-practices`, `#setting-component-state`
- [ ] Assertions: `wrapper.props('x')` over `wrapper.vm.x`; `toEqual` on `props()` for many props; `toMatchObject` over `expect.objectContaining`. — `fe_guide/style/vue.md#accessing-component-state`
- [ ] Child components: test `v-if`/`v-for`, props passed (`.props()`), reactions to emitted events; **do not** test child internals. — `fe_guide/vue.md#child-components`
- [ ] Events: `trigger` for native DOM events on real elements; `vm.$emit` on child components ("prefer to use `vm.$emit` over `trigger` when emitting events from child components"); assert via `emitted()`. — `fe_guide/vue.md#events`
- [ ] Selectors: best `findByRole`/`findByText`; good `findComponent`, `[data-testid]`, `findByTestId`; bad `{ ref }`, `.js-*`, `.gl-button`. Don't add `.js-*` classes just for tests. `data-testid` kebab-case. — `#how-to-query-dom-elements`
- [ ] Jest matchers: `toBe` for primitives; specific matchers; avoid `toBeTruthy`/`toBeFalsy`; avoid `setImmediate`. — `#jest-best-practices`
- [ ] Deterministic specs: fake `Date` and `Math.random`. — `#avoid-non-deterministic-specs`
- [ ] **Snapshots**: "should **only** be used when other testing methods … do not cover the required use case." Use for protecting critical HTML structures or complex utility JSON output. Don't use when direct assertions would work, to assert component logic, to predict data structures, or when the HTML comes from outside the repo (a third-party component library). "the cons of snapshot tests far outweigh the pros in general." — `#snapshots`, `#when-to-use`, `#when-not-to-use`
- [ ] Apollo tests use the mock Apollo helper; prefer controlled mode. — `fe_guide/graphql.md#mocking-apollo-client`, `#mock-apollo-helper-controlled-resolution`
- [ ] Feature tests only when spanning multiple components or pages, a form submit with results elsewhere, or excessive mocking otherwise; default to request-mocked integration tests over full browser-driven ones unless a real backend, database, authorization path, or licensed-versus-base difference is needed. — `#when-to-use-feature-tests`, `#when-not-to-use-feature-tests`, `#choose-the-right-feature-test-type`
- [ ] Page-entry `pages/**/index.js` files are exempt from unit tests and must stay thin ("import, read the DOM, instantiate, and nothing else"). — `fe_guide/performance.md#important-considerations`

### B9. Performance

Source: `fe_guide/performance.md` — `https://docs.gitlab.com/development/fe_guide/performance/`

- [ ] "**Do not add** anything to [`main.js` / `commons/index.js`] unless it is truly needed _everywhere_." — `#universal-code`
- [ ] Page-specific JS via `pages/<controller>/<action>/index.js` auto-entries; never hand-edit `webpack.config.js` entries; no `DOMContentLoaded` (scripts are `defer`red). — `#page-specific-javascript`, `#important-considerations`; also `fe_guide/style/javascript.md#do-not-use-domcontentloaded-in-non-page-modules`
- [ ] Non-immediate code (modals, dropdowns) split with dynamic `import()` and a `webpackChunkName`. — `#code-splitting`
- [ ] Page size: no new fonts; avoid new libraries when reasonably avoidable; lazy-load via code splitting. — `#minimizing-page-size`
- [ ] New JS library significantly increasing bundle size needs Frontend Design System approval; unapproved license needs Legal. — `code_review.md#approval-guidelines`
- [ ] Real-time: honor `Poll-Interval` header (`-1` disables), stop on non-2XX, poll only on visible tabs, no backoff/jitter, don't check 304. — `#real-time-components`
- [ ] Images lazy-loaded (`data-src` + `lazy`; Rails `image_tag` default). — `#lazy-loading-images`
- [ ] Animate only `opacity` and `transform`; FLIP for layout changes. — `#animations`
- [ ] Constants exported as primitives (helps bundle size). — `fe_guide/style/javascript.md#export-constants-as-primitives`
- [ ] Goals: fewest Vue apps per page; ViewComponents for simple pages. — `fe_guide/_index.md#goals`

### B10. JavaScript style and security items a reviewer checks

Source: `fe_guide/style/javascript.md` — `https://docs.gitlab.com/development/fe_guide/style/javascript/`

- [ ] Airbnb style via ESLint; `yarn run lint:eslint $PATH`. — top of page
- [ ] "Do not use `innerHTML`, `append()` or `html()` to set content." — `#avoid-xss`; see also `secure_coding_guidelines/_index.md#xss-mitigation-and-prevention-in-javascript-and-vue`
- [ ] No `forEach` for mutation; `map`/`reduce`/`filter`. — `#avoid-foreach`
- [ ] More than 3 params → object argument. — `#limit-number-of-parameters`
- [ ] `parseInt` **must** include radix; prefer `Number`. — `#converting-strings-to-integers`
- [ ] `js-` prefix for JS-only CSS hooks. — `#css-selectors---use-js--prefix`
- [ ] Named ES exports (default only for SFCs and Vuex mutation files); relative imports under two levels up, `~/` otherwise; no globals; no IIFEs; no top-level side effects in modules with `export`; no side effects in constructors. — `#es-module-syntax`, `#absolute-vs-relative-paths-for-modules`, `#global-namespace`, `#iifes`, `#side-effects`
- [ ] Readiness signals for feature tests use scoped `data-*` attributes, not timer classes. — `#readiness-signals`
- [ ] Error handling: generic message for 500s; `parseErrorMessage` with `Gitlab::Utils::ErrorMessage.to_user_facing` prefixing (not for API responses). — `#error-handling`
- [ ] If the project separates a licensed or enterprise code path from the open one, frontend code on that path lives where its own convention puts it, and is imported through whatever aliasing that convention provides (including the fall-back-to-base form) rather than by reaching across the boundary with a relative path. `n/a` where there is no such split. — `ee_features.md#separation-of-ee-code-in-the-frontend`

### B11. Review routing specific to frontend MRs

- [ ] Haml changes: frontend review for DOM/CSS/a11y/interaction; backend for Ruby logic; both when intertwined. — `code_review.md#approval-guidelines` footnote 1
- [ ] Any visual or screen-reader-affecting DOM change is `~UX` and needs a Product Designer where the group has one (always for community contributions). — footnote 3
- [ ] Before/After screenshots required for UI changes; list affected pages when changing CSS classes. — `contributing/merge_request_workflow.md#ui-changes`
- [ ] Test in all supported browsers or justify not doing so. — `code_review.md#quality` item 6

---

# Applying this checklist in the skill

## Applicability by repo

The checklist above is written against a large Vue application with a page-bootstrap global
for flags, a separate licensed code tree, store libraries, Storybook and an i18n pipeline. **Most projects
have only some of that.** Read every item through the stack the profile declares, and record
the ones the project does not have as `n/a` with the reason — never skip them silently.

The profile is what says which apply. It should state: the framework and major version, the
GraphQL client, the component library, the CSS approach, the bundler, the test runner and
where its specs live, how feature flags reach the frontend, and whether the project has an
i18n pipeline, a Storybook, or a separate enterprise tree.

Worked example of how a profile narrows this (a project whose profile declares Vue 2.7,
Apollo Client 3, a shared component library, Tailwind, Vite and Jest, with no store library,
no page-bootstrap global, and no separate licensed tree):

| Area | How the profile narrows it |
|---|---|
| B1 structure, B2 props | as written; the project's own frontend skill adds: every component has a `name`, typed props, no mutated props, no reaching into parent or child instances, no business logic in components, no direct DOM manipulation, no global event bus, components under 300 lines |
| B3 state management | component data → provide/inject → the GraphQL client's cache as the single source of truth; flag any store introduction |
| B4 GraphQL client | as written for fragments, `id` on every type, errors-as-data, pagination; the category-annotation comments and client-directive CI validation are specific to the upstream project |
| B5 accessibility | as written; the automated axe job is specific to the upstream project, so check by reading and by an accessibility snapshot in Phase 5 |
| B6 i18n | `n/a`; this project's UI copy is single-language, but the no-concatenation rule still keeps copy reviewable |
| B7 feature flags | flags reach the frontend through GraphQL fields or props, not a page-bootstrap global; check both states in Phase 5 |
| B8 test runner | as written; specs live where the profile says, run with the profile's command |
| B9 performance | the upstream bundle rules do not apply; still flag a new dependency in the manifest |
| B11 routing | the profile's category map decides which checklists a changed file pulls in |

If the project ships its own frontend skill or conventions doc, that is authoritative for
conventions; load it for any frontend change and record its anti-pattern table in the
Phase 4 verdicts.
