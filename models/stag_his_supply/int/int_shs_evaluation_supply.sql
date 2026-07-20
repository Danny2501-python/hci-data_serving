with sessr as (
    select * from {{ ref('stg_shs_sh_evaluation_supply_service_rel') }}
),
smes as (
    select * from {{ ref('stg_shs_sh_medical_evaluation_supply') }}
),
sme as (
    select * from {{ ref('stg_shs_sh_medical_evaluation') }}
)

select
    'evaluation' as data_union, smes.id, smes.name, smes.qty, smes.uom_id, smes.supply, smes.notes, smes.qty_used,
    smes.location_id, smes.medicament_type, smes.sequence, smes.create_uid, smes.create_date, smes.write_uid, smes.write_date,
    smes.picking_id, null as explanation_supply, sme.id as form_id, sme.name as form_name, sme.evaluation_start_date as services_date, sme.patient,
    sessr.sh_medical_health_center_service_id as service_id, sme.walkin as walkinid,
    sme.ward as ward_id, sme.room as room_id, sme.institution, 'Surgery'::character varying as department_type,
    sessr.brand_etl
from sessr
left join smes on sessr.sh_medical_evaluation_supply_id = smes.id and sessr.brand_etl = smes.brand_etl
left join sme on smes.name = sme.id and sme.brand_etl = smes.brand_etl
where sme.state = 'Completed' and sessr.brand_etl <> 0
