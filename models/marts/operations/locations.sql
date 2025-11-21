with

locations as (

    select * from {{ ref('stg_jaffle_shop__locations') }}

)

select * from locations
