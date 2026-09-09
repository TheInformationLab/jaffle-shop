---
name: model-code-standards
description: Use whenever writing, editing, or reviewing dbt SQL models (.sql files under models/) — check for style, naming, and anti-pattern violations before treating a model as done. Trigger this any time the user asks to "review", "lint", "check", "clean up", or "refactor" a dbt model, or whenever you yourself write or modify dbt model SQL, even if the user didn't explicitly ask for a review. Covers comma style, indentation, snake_case naming, boolean flag prefixes, SELECT *, USING() joins, CTE vs subquery structure, hardcoded table references vs ref()/source(), and meaningful naming.
metadata:
  author: ollie-clarke
---

# Reviewing dbt SQL style

Check dbt model SQL against this team's style guide and flag every violation before calling a model finished. This is a manual/heuristic review — it does not replace `sqlfluff` or `dbt_project_evaluator` for CI enforcement; use this skill for in-conversation review and edits.

## When to use

- The user pastes or references a `.sql` model and asks for a review, lint, cleanup, or refactor.
- You are about to write a new dbt model or edit an existing one — run this checklist on your own output before presenting it.
- The user asks "does this follow our conventions" or similar, even without naming a specific rule.

Do not apply this skill to raw analytical/ad-hoc SQL that isn't a dbt model (e.g. a one-off query in a notebook) unless the user asks you to.

## Workflow

1. Read the full model file (and its schema YAML if present, for existing column/test context).
2. Walk the checklist below top to bottom. For each rule, note every violation with a line reference — don't stop at the first hit per rule.
3. Report findings as a table: `Rule | Location | Current | Suggested fix`.
4. If asked to fix rather than just review, apply minimal-diff edits — preserve the model's logic and existing structure; don't restructure things the checklist doesn't cover (e.g. don't reorder CTEs, rename unrelated columns, or change materialization) unless asked.
5. If a rule genuinely can't be satisfied (e.g. a join truly has no other option than `USING`), say so explicitly rather than silently skipping it — flag it as an accepted exception, not a pass.

## Checklist

### 1. Leading commas
Commas go at the start of the line, not the end, in `SELECT` lists and column definitions.

```sql
-- Bad
select
    order_id,
    customer_id,
    order_date

-- Good
select
    order_id
    , customer_id
    , order_date
```

### 2. Indentation
Use 4 spaces (not tabs) per indent level. Keywords (`select`, `from`, `where`, `group by`) sit at the base indent; their contents are indented one level in.

### 3. snake_case naming
All model names, CTE names, column aliases, and file names use `snake_case`. Flag `camelCase`, `PascalCase`, or `kebab-case` anywhere in identifiers.

```sql
-- Bad
select orderId, customerFirstName

-- Good
select order_id, customer_first_name
```

### 4. Boolean flag prefixes
Boolean columns are prefixed `is_`, `has_`, or `does_` (whichever reads naturally) — never a bare adjective or ambiguous name.

```sql
-- Bad
active, deleted, valid_flag

-- Good
is_active, is_deleted, is_valid
```

### 5. No `select *`
Every `select` lists explicit columns, including in CTEs. Flag `select *` and `select table.*` alike.

### 6. No `USING()` joins
Joins use explicit `ON` with fully qualified column references, not `USING (column)`.

```sql
-- Bad
from orders
join customers using (customer_id)

-- Good
from orders
join customers
    on orders.customer_id = customers.customer_id
```

### 7. CTEs, not subqueries
Nested subqueries in the `FROM` or `JOIN` clause should be pulled out into named CTEs at the top of the model. A model should read top-to-bottom as a sequence of named, single-purpose CTEs ending in a final `select` — not nested parentheses.

```sql
-- Bad
select *
from (
    select customer_id, sum(amount) as total
    from orders
    group by 1
) as agg

-- Good
with order_totals as (
    select
        customer_id
        , sum(amount) as total
    from orders
    group by 1
)

select * from order_totals
```

### 8. No hardcoded table references
Every table reference is `{{ ref('model_name') }}` or `{{ source('source_name', 'table_name') }}`. Flag any bare `database.schema.table`, `schema.table`, or raw table name in a `FROM`/`JOIN` clause.

```sql
-- Bad
from analytics.staging.stg_orders

-- Good
from {{ ref('stg_orders') }}
```

### 9. Meaningful, dbt-convention names
- Model file names follow the layer prefix convention: `stg_` (staging), `int_` (intermediate), `fct_`/`dim_` (marts fact/dimension) — flag models with no prefix or the wrong one for their layer.
- Column and CTE names describe content, not mechanism — flag names like `t1`, `tmp`, `data`, `final_final`, `cte2`.
- Avoid needless abbreviation; prefer `customer_id` over `cust_id` unless the abbreviation is already the team standard elsewhere in the project (check for existing precedent before flagging).

## Output format

When reviewing (not fixing), respond with:

```
| Rule | Location | Current | Suggested fix |
|---|---|---|---|
```

followed by a one-line summary count ("7 violations across 4 rules"). Don't rewrite the whole file inline unless asked — show the fix per row, or offer to apply all fixes as an edit.