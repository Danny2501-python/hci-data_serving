with smprm as (
    select
        id, name, qty, uom_id, medicine as supply, notes, qty as qty_used,
        location_id, medicament_type, sequence, create_uid, create_date, write_uid, write_date,
        picking_id, dosage as explanation_supply, brand_etl
    from {{ ref('stg_shs_sh_medical_patient_rounding_medicines') }}
    where brand_etl <> 0
),
smpr as (
    select * from {{ ref('stg_shs_sh_medical_patient_rounding') }}
),
srsr as (
    select * from {{ ref('stg_shs_sh_rounding_service_rel') }}
),
smi as (
    select * from {{ ref('stg_shs_sh_medical_inpatient') }}
)

select
    'inpatient' as data_union, smprm.id, smprm.name, smprm.qty, smprm.uom_id, smprm.supply, smprm.notes, smprm.qty_used,
    smprm.location_id, smprm.medicament_type, smprm.sequence, smprm.create_uid, smprm.create_date, smprm.write_uid, smprm.write_date,
    smprm.picking_id, smprm.explanation_supply, smpr.id as form_id, smpr.name as form_name, smpr.evaluation_end_date as services_date, smpr.patient,
    srsr.sh_medical_health_center_service_id as service_id,
    smpr.walkin as walkinid, smi.ward as ward_id, smi.room as room_id, smi.institution, 'Surgery'::character varying as department_type,
    smprm.brand_etl
from smprm
left join smpr on smpr.id = smprm.name and smpr.brand_etl = smprm.brand_etl
left join srsr on srsr.sh_medical_patient_rounding_id = smpr.id and srsr.brand_etl = smpr.brand_etl
left join smi on smi.id = smpr.inpatient_id and smi.brand_etl = smpr.brand_etl
where smpr.state = 'Completed'
