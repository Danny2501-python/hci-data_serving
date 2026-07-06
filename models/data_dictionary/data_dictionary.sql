with base_columns as (
    select
        c.table_schema,
        c.table_name,
        c.column_name,
        c.data_type,
        c.ordinal_position
    from information_schema.columns c
    where c.table_schema = 'public'
),

column_descriptions as (
    select
        n.nspname   as table_schema,
        cls.relname as table_name,
        attr.attname as column_name,
        descr.description
    from pg_catalog.pg_description descr
    join pg_catalog.pg_attribute attr
        on attr.attrelid = descr.objoid
        and attr.attnum  = descr.objsubid
    join pg_catalog.pg_class cls
        on cls.oid = descr.objoid
    join pg_catalog.pg_namespace n
        on n.oid = cls.relnamespace
    where attr.attnum > 0
)

select
    bc.table_name                        as ten_bang,
    bc.column_name                       as ten_cot,
    coalesce(cd.description, '')         as mo_ta,
    bc.data_type                         as kieu_du_lieu,
    current_timestamp                    as ngay_tao,
    current_timestamp                    as ngay_sua,
    false                                as xoa
from base_columns bc
left join column_descriptions cd
    on  cd.table_schema = bc.table_schema
    and cd.table_name   = bc.table_name
    and cd.column_name  = bc.column_name
order by bc.table_name, bc.ordinal_position
