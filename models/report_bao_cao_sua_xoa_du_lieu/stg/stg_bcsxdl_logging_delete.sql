select
    *
from
    {{ source('bao_cao_sua_xoa_du_lieu', 'logging_delete') }} ldp
where
    ldp.table_name = 'crm_sale_payment'