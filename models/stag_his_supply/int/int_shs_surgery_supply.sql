with ssurgssr as (
    select * from {{ ref('stg_shs_sh_surgery_supply_service_rel') }}
),
smssurg as (
    select * from {{ ref('stg_shs_sh_medical_surgery_supply') }}
),
smsurg as (
    select * from {{ ref('stg_shs_sh_medical_surgery') }}
)

select
    'surgery' as data_union, smssurg.id, smssurg.name, smssurg.qty, smssurg.uom_id, smssurg.supply, smssurg.notes, smssurg.qty_used,
    smssurg.location_id, smssurg.medicament_type, smssurg.sequence, smssurg.create_uid, smssurg.create_date, smssurg.write_uid, smssurg.write_date,
    smssurg.picking_id, smssurg.explanation_supply, smsurg.id as form_id, smsurg.name as form_name, smsurg.surgery_date as services_date, smsurg.patient,
    ssurgssr.sh_medical_health_center_service_id as service_id, smsurg.walkin as walkinid,
    smsurg.department as ward_id, smsurg.operating_room as room_id, smsurg.institution, smsurg.department_type,
    ssurgssr.brand_etl
from ssurgssr
left join smssurg on ssurgssr.sh_medical_surgery_supply_id = smssurg.id and ssurgssr.brand_etl = smssurg.brand_etl
left join smsurg on smssurg.name = smsurg.id and smssurg.brand_etl = smsurg.brand_etl
where smsurg.state = 'Done' and ssurgssr.brand_etl <> 0
