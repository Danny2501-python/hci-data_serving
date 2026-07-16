with ssssr as (
    select * from {{ ref('stg_shs_sh_surgery_specialty_service_rel') }}
),
smss as (
    select * from {{ ref('stg_shs_sh_medical_specialty_supply') }}
),
sms as (
    select * from {{ ref('stg_shs_sh_medical_specialty') }}
)

select
    'specialty' as data_union, smss.id, smss.name, smss.qty, smss.uom_id, smss.supply, smss.notes, smss.qty_used,
    smss.location_id, smss.medicament_type, smss.sequence, smss.create_uid, smss.create_date, smss.write_uid, smss.write_date,
    smss.picking_id, smss.explanation_supply, sms.id as form_id, sms.name as form_name, sms.services_date, sms.patient,
    ssssr.sh_medical_health_center_service_id as service_id, sms.walkin as walkinid,
    sms.department as ward_id, sms.perform_room as room_id, sms.institution, sms.department_type,
    ssssr.brand_etl
from ssssr
left join smss on ssssr.sh_medical_specialty_supply_id = smss.id and ssssr.brand_etl = smss.brand_etl
left join sms on smss.name = sms.id and sms.brand_etl = smss.brand_etl
where sms.state = 'Done' and ssssr.brand_etl <> 0
