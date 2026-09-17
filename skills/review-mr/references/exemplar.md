# Exemplar — the shape every summary and diff note must match

A worked example showing the shape every summary and diff note should match. Rules describe
the shape; this file shows it. When a drafted body does not look like these, the draft is
wrong, not the exemplar. Every identifier here is invented — `app/models/example/…`,
`Order`, `@author-handle`, `<link to …>` — so the techniques transfer to any codebase.

## 1. The summary reply (one per change request, posted last, as a reply in the author's review-request thread)

What to notice: opens with the handle and one specific thing done well; states what was
checked with the spec scope named as *targeted*; counts the diff threads by label; names
the single gating thread and says why it gates; says what would settle the one thread whose
weight is still open; one clause for the point with no diff line. Six sentences, no
headings, no per-thread list, no local ids, no tool output.

```
@author-handle thanks for this, nicely mirrored on the `line_items` path and well covered by specs.

Checked out the branch, ran the targeted specs for the changed files and their callers (372 examples, 0 failures) and the linter on the changed files, and exercised the new query and the API field locally.

I left four threads on the diff: one **issue (blocking)** on the top-level `categories` filter, and three non-blocking questions and suggestions. One nit outside the diff: the CI bot's commit-message warnings still apply; only the squash message matters.

Happy to approve once the `categories` thread is settled, since it decides the contract the client side will code against. On the performance thread, whether it needs anything before merge depends on what the query costs on staging or production for a large account; rows read and memory from there would settle it.
```

## 2. A diff note carrying a finding (anchored on the line that introduces the behaviour)

Anchor: `app/graphql/types/example/order_totals/customer_type.rb:62`, the resolver line the
suggestion replaces. What to notice: bold label with an explicit decoration; one plain
sentence saying what is wrong for the user of the API; every code reference is a link to the
head commit with the line quoted; the reproduction is a scenario ("a customer whose orders
are all of one category"), never an id; the consumer that will hit the bug is named and
linked; a sibling precedent is shown; the ask is a question, not an order; the suggestion
block is exact and compiles; the last line says which spec would pin the behaviour.

```
**issue (blocking):** the new field ignores the top-level `categories` filter, so `monthlyTotals` and `totalSpend` can disagree in the same response.

There are two places a caller can filter by category, and the new field only honours one of them.

- The top-level filter is an argument on the parent: `orderTotals(categories: [...])`. [`order_totals_type.rb:52`](<link to the file at the head commit, line 52>) passes it into every `Customer` object as `categories`.
- The existing `totalSpend` field honours that top-level filter: [`order_totals_helper.rb:10`](<link to the file at the head commit, line 10>) reads `object.categories`.
- The new resolver reads only its own field argument, at [`customer_type.rb:62`](<link to the file at the head commit, line 62>):
  > `object.monthly_totals(categories: categories)`
  so with a top-level filter and no field argument the series is unfiltered.
- I reproduced it locally with a customer whose orders are all of one category, requesting a top-level filter for a *different* category and no field argument:
  - `totalSpend` came back `0.0` (correctly filtered);
  - `monthlyTotals` came back with the customer's full monthly total (not filtered);
  - so the same response shows a zero total above a non-empty chart.
- This is the path the dashboard will take: the client's per-customer query passes `categories` at the top level ([`GET_ORDER_TOTALS_QUERY` in the client's reporting module](<link to the consumer in the client repo>)).
- For comparison, the account-level `monthlyTotals` has no field argument and uses the top-level filter: [`account_totals_type.rb:111-112`](<link to the file at the head commit, lines 111-112>).

What do you think about falling back to the object's filter when the field argument is absent, so the argument remains an override?

```suggestion:-0+0
            object.monthly_totals(categories: categories || object.categories)
```

`Customer#monthly_totals` already applies `.presence`, so an empty array still means "no filter". A request-spec example with a top-level `categories` and no field argument would pin the behaviour.
```

## 3. A diff note carrying a question to the author and a domain expert (anchored on the method `def`)

Anchor: `app/models/example/order_totals/customer.rb:59`, `def monthly_totals`. What to
notice: the issue's acceptance criterion is quoted verbatim with a link, never called
"AC3"; each side of the disagreement is traced to a file and line; the local check is a
scenario with only the two numbers whose relationship carries the point; the ask names
what the description should say, and cc's the issue author for the intent question the
reviewer cannot settle from code.

```
**question (non-blocking):** one acceptance criterion in the issue cannot hold with the new reporting data source; should it be restated?

The [issue](<link to the issue>) description lists as its third acceptance criterion:
> Reconciles with the existing aggregate `OrderTotals.monthlyTotals` when only one customer has orders.

- `OrderTotals.monthlyTotals` is the existing account-level field. It is computed in the primary database at [`order_totals.rb:20-22`](<link to the file at the head commit, lines 20-22>):
  > `Ledger::Entry.monthly_totals(prepaid_entries, start_date, end_date)`
  i.e. it sums entries against the customers' **prepaid balances** only.
- The new per-customer field sums the order records themselves, which also includes what was charged to the shared account credit line once a prepaid balance runs out.
- So the two agree only while a customer stays inside their prepaid balance. I tried it locally with one account and three customers in a single month, where two of the three had spent more than their prepaid balance:
  - the prepaid-balance series (`OrderTotals#monthly_totals`) totalled **58** for the month, because those two customers were capped at their balance;
  - the new order-record series totalled **75** across the same three customers, because it also counts what spilled onto the account credit line.
- What does hold with the new source is `sum(monthlyTotals) == totalSpend` for the same customer and filter, which is what a per-customer dashboard needs.

Could the description state that the data source was switched deliberately, and that the series reconciles with `totalSpend` rather than with `OrderTotals.monthlyTotals`? @domain-expert-handle, as the issue author, could you confirm that reading of the criterion?
```

## What is deliberately absent from all three

No file paths outside links, no local account names or ids, no tool output, no
"AC3"-style shorthand, no mention of how the review was produced, no per-thread list in the
summary, and no gating on a thread whose own label says non-blocking.
