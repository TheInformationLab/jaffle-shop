with

supplies as (

    select * from {{ ref('stg_jaffle_shop__supplies') }}

)

select * from supplies
