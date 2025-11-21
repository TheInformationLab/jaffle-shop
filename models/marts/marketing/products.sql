with

products as (

    select * from {{ ref('stg_jaffle_shop__products') }}

)

select * from products
