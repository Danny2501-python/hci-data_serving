select
    value_id,
    trim(both from split_part(value_lable, ']', 2)) as value_lable
from {{ source('rck_base', 'cs_custom_fields') }}
