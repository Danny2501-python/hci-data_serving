select
    *
from
    {{ source('bao_cao_sua_xoa_du_lieu', 'auditlog_log') }} al
where
    al.model_id = 868