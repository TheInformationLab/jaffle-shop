# Extended SQL anti-patterns

Anti-patterns beyond the 9 named rules in SKILL.md. Check these too during a review, but report them as a separate "Additional findings" section below the main rule table — they're real issues, just not part of the core numbered checklist, so don't renumber them into rules 1-9.

## Contents
- Null-dropping filters
- Unnecessary CROSS JOIN
- Fanout-masking DISTINCT
- Orphaned / unused CTEs
- Windows without deterministic ORDER BY
- Redundant CAST
- Hardcoded dates instead of variables
- Full table scans on incremental models
- Unqualified columns in multi-table queries
- Ordinal GROUP BY / ORDER BY on wide selects

---

## Null-dropping filters

`!=` and `NOT IN` silently exclude rows where the compared column is `NULL`, because `NULL != x` evaluates to `NULL`, not `true`. This is a common source of quietly-shrinking row counts.

```sql
-- Bad: rows where status is NULL are dropped, not just 'cancelled' rows
where status != 'cancelled'

-- Good: explicit about nulls
where (status != 'cancelled' or status is null)
-- or, if nulls should also be excluded, say so explicitly:
where status is distinct from 'cancelled'
```

## Unnecessary CROSS JOIN

An explicit `CROSS JOIN` (or a comma join with no `WHERE` linking the tables) is almost always a missing join condition, not an intended cartesian product. Flag it unless the model is deliberately generating a date spine, a combination table, or similar — in which case a comment should say so.

```sql
-- Bad: looks accidental
from orders
cross join customers

-- Good: intentional and documented
-- generate one row per (date, region) combination for the spine
from date_spine
cross join regions
```

## Fanout-masking DISTINCT

A bare `select distinct` at the end of a model that joins one-to-many tables usually means a join fanout is being papered over rather than fixed. Flag it and ask whether the join grain is actually correct.

```sql
-- Bad: distinct hides that orders join line_items 1:many
select distinct order_id, customer_id
from orders
join order_line_items using (order_id)

-- Good: aggregate to the intended grain instead
select
    order_id
    , customer_id
    , count(*) as line_item_count
from orders
join order_line_items
    on orders.order_id = order_line_items.order_id
group by 1, 2
```

## Orphaned / unused CTEs

A CTE defined with `with` but never referenced downstream, or a CTE that exists solely to rename columns with no other transformation, adds noise without value. Flag both: dead CTEs should be removed, and pass-through rename-only CTEs should usually be folded into the CTE that produces the columns.

## Windows without deterministic ORDER BY

A window function (`row_number()`, `rank()`, `lag()`, etc.) whose `ORDER BY` doesn't produce a unique ordering will return different results across runs when there are ties. Flag any window `ORDER BY` that isn't guaranteed unique (add a tiebreaker column, typically a surrogate or primary key).

```sql
-- Bad: ties on order_date get an arbitrary row_number
row_number() over (partition by customer_id order by order_date)

-- Good: tiebreaker makes the ordering deterministic
row_number() over (partition by customer_id order by order_date, order_id)
```

## Redundant CAST

Casting a column to the type it already is, or casting a literal that dbt/the warehouse will already infer correctly, adds clutter. Distinguish this from a *necessary* cast (e.g. casting a warehouse-inferred `NUMBER` to `INTEGER` to avoid precision surprises, or casting a source's string date column to `DATE`) — only flag casts that do nothing.

## Hardcoded dates instead of variables

A literal date or timestamp in a `WHERE` clause (`where order_date >= '2024-01-01'`) breaks the moment the model needs re-running for a different period, and silently goes stale. Use `{{ var('start_date') }}`, `{{ dbt.current_timestamp() }}`, or an incremental filter (see below) instead.

```sql
-- Bad
where order_date >= '2024-01-01'

-- Good
where order_date >= {{ var('start_date', "'2024-01-01'") }}
```

## Full table scans on incremental models

A model configured as `materialized='incremental'` that doesn't filter on the incremental predicate inside `{% if is_incremental() %}` re-scans the full source table every run, defeating the point of incremental materialization. Flag incremental models with no `is_incremental()` block, or one that doesn't actually filter the source.

```sql
-- Bad: incremental config but no filter — scans everything every run
{{ config(materialized='incremental') }}
select * from {{ source('raw', 'events') }}

-- Good
{{ config(materialized='incremental') }}
select * from {{ source('raw', 'events') }}
{% if is_incremental() %}
where event_timestamp > (select max(event_timestamp) from {{ this }})
{% endif %}
```

## Unqualified columns in multi-table queries

Once a query joins more than one table, every column reference should be qualified with its table (or CTE) name or alias — even columns that aren't currently ambiguous. An unqualified column becomes a silent bug the moment either table gains a column with that name.

```sql
-- Bad: which table is customer_id from?
select customer_id, order_date
from orders
join customers on orders.customer_id = customers.customer_id

-- Good
select
    orders.customer_id
    , orders.order_date
from orders
join customers
    on orders.customer_id = customers.customer_id
```

## Ordinal GROUP BY / ORDER BY on wide selects

`group by 1, 2` and `order by 3` are fine on short, stable selects, but on a wide or frequently-edited select list they silently regroup/reorder when a column is inserted earlier in the list. Flag ordinal grouping/ordering on selects wider than ~5 columns, or on any model that changes often, and suggest naming the columns explicitly instead.