-- Bảng stg_rpcas_phone_call_history: Bảng lịch sử phone call
select
    cpch.*,
    case
        when cpch.phone_call_id is null then cpch.res_id
        else cpch.phone_call_id
    end as id_phonecall
from
    {{ source('phone_call_after_service','crm_phone_call_history')}} cpch
where
    cpch.phone_call_id is not null
    or cpch.res_model = 'crm.phone.call'