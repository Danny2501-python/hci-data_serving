select
    value_id,
    value_lable
from {{ source('rtc_base', 'cs_custom_fields_thv') }}
