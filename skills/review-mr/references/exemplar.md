# Exemplar — the shape every summary and diff note must match

Taken from customers-gitlab-com !17037 (2026-09-07), the review the user signed off as
"exactly how a review should look". Rules describe the shape; this file shows it. When a
drafted body does not look like these, the draft is wrong, not the exemplar.

## 1. The summary reply (one per MR, posted last, as a reply in the author's review-request thread)

What to notice: opens with the handle and one specific thing done well; states what was
checked with the spec scope named as *targeted*; counts the diff threads by label; names
the single gating thread and says why it gates; says what would settle the one thread whose
weight is still open; one clause for the point with no diff line. Six sentences, no
headings, no per-thread list, no local ids, no tool output.

```
@hvardhansharma-ext thanks for this MR, nicely mirrored on the `events` path and well covered by specs.

Checked out the branch, ran the targeted specs for the changed files and their callers (372 examples, 0 failures) and RuboCop on the changed files, and exercised the new query and the GraphQL field locally.

I left four threads on the diff: one **issue (blocking)** on the top-level `flowTypes` filter, and three non-blocking questions and suggestions. One nit outside the diff: Danger's commit-message warnings still apply; only the squash message matters.

Happy to approve once the `flowTypes` thread is settled, since it decides the contract the GitLab side will code against. On the performance thread, whether it needs anything before merge depends on what the query costs on staging or production for a large subscription; rows read and memory from there would settle it.
```

## 2. A diff note carrying a finding (anchored on the line that introduces the behaviour)

Anchor: `app/graphql/types/subscriptions/gitlab_credits/users_usage/user_type.rb:62`, the
resolver line the suggestion replaces. What to notice: bold label with an explicit
decoration; one plain sentence saying what is wrong for the user of the API; every code
reference is a link to the head commit with the line quoted; the reproduction is a scenario
("a user whose events are all of one flow type"), never an id; the consumer that will hit
the bug is named and linked; a sibling precedent is shown; the ask is a question, not an
order; the suggestion block is exact and compiles; the last line says which spec would pin
the behaviour.

```
**issue (blocking):** the new field ignores the top-level `flowTypes` filter, so `dailyUsage` and `totalCreditsUsed` can disagree in the same response.

There are two places a caller can filter by flow type, and the new field only honours one of them.

- The top-level filter is an argument on the parent: `gitlabCreditsUsage(flowTypes: [...])`. [`users_usage_type.rb:52`](https://gitlab.com/gitlab-org/customers-gitlab-com/-/blob/a70e25af9e5e7cab081aaa386dc0494cfbc033f0/app/graphql/types/subscriptions/gitlab_credits/users_usage_type.rb#L52) passes it into every `User` object as `flow_types`.
- The existing `totalCreditsUsed` field honours that top-level filter: [`users_usage_helper.rb:10`](https://gitlab.com/gitlab-org/customers-gitlab-com/-/blob/a70e25af9e5e7cab081aaa386dc0494cfbc033f0/app/helpers/graphql/users_usage_helper.rb#L10) reads `object.flow_types`.
- The new resolver reads only its own field argument, at [`user_type.rb:62`](https://gitlab.com/gitlab-org/customers-gitlab-com/-/blob/a70e25af9e5e7cab081aaa386dc0494cfbc033f0/app/graphql/types/subscriptions/gitlab_credits/users_usage/user_type.rb#L62):
  > `object.daily_usage(flow_types: flow_types)`
  so with a top-level filter and no field argument the series is unfiltered.
- I reproduced it locally with a user whose events are all of one flow type, requesting a top-level filter for a *different* flow type and no field argument:
  - `totalCreditsUsed` came back `0.0` (correctly filtered);
  - `dailyUsage` came back with the user's full daily total (not filtered);
  - so the same response shows a zero total above a non-empty chart.
- This is the path the dashboard will take: GitLab's per-user query passes `flowTypes` at the top level ([`GET_USERS_USAGE_QUERY` in `subscription_usage_client.rb`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/gitlab/subscription_portal/subscription_usage_client.rb)).
- For comparison, the subscription-level `dailyUsage` has no field argument and uses the top-level filter: [`usage_type.rb:111-112`](https://gitlab.com/gitlab-org/customers-gitlab-com/-/blob/a70e25af9e5e7cab081aaa386dc0494cfbc033f0/app/graphql/types/subscriptions/gitlab_credits/usage_type.rb#L111-112).

What do you think about falling back to the object's filter when the field argument is absent, so the argument remains an override?

```suggestion:-0+0
            object.daily_usage(flow_types: flow_types || object.flow_types)
```

`User#daily_usage` already applies `.presence`, so an empty array still means "no filter". A request-spec example with a top-level `flowTypes` and no field argument would pin the behaviour.
```

## 3. A diff note carrying a question to the author and a domain expert (anchored on the method `def`)

Anchor: `app/models/gitlab_credits/users_usages/user.rb:59`, `def daily_usage`. What to
notice: the issue's acceptance criterion is quoted verbatim with a link, never called
"AC3"; each side of the disagreement is traced to a file and line; the local check is a
scenario with only the two numbers whose relationship carries the point; the ask names
what the description should say, and cc's the issue author for the intent question the
reviewer cannot settle from code.

```
**question (non-blocking):** one acceptance criterion in the issue cannot hold with the ClickHouse source; should it be restated?

The [issue](https://gitlab.com/gitlab-org/gitlab/-/work_items/605985) description lists as its third acceptance criterion:
> Reconciles with the existing aggregate `UsersUsage.dailyUsage` when only one user has usage.

- `UsersUsage.dailyUsage` is the existing subscription-level field. It is computed in Postgres at [`users_usage.rb:20-22`](https://gitlab.com/gitlab-org/customers-gitlab-com/-/blob/a70e25af9e5e7cab081aaa386dc0494cfbc033f0/app/models/gitlab_credits/users_usage.rb#L20-22):
  > `Wallets::Transaction.daily_usage(consumer_transactions, start_date, end_date)`
  i.e. it sums debits on the users' **consumer wallets** only (each user's included allocation).
- The new per-user field sums `GitlabCredits` on enriched events, which also includes credits drawn from the shared subscription wallets once the allocation is used up.
- So the two agree only while a user stays inside their allocation. I tried it locally with one subscription and three users on a single day, where two of the three had used more than their included allocation:
  - the consumer-wallet series (`UsersUsage#daily_usage`) totalled **58** for the day, because those two users were capped at their allocation;
  - the new event-based per-user series totalled **75** across the same three users, because it also counts what spilled into the subscription wallets.
- What does hold with the ClickHouse source is `sum(dailyUsage) == totalCreditsUsed` for the same user and filter, which is what a per-user dashboard needs.

Could the description state that the data source was switched deliberately, and that the series reconciles with `totalCreditsUsed` rather than with `UsersUsage.dailyUsage`? @sheldonled, as the issue author, could you confirm that reading of the criterion?
```

## What is deliberately absent from all three

No file paths outside links, no local subscription names or ids, no tool output, no
"AC3"-style shorthand, no mention of how the review was produced, no per-thread list in the
summary, and no gating on a thread whose own label says non-blocking.
