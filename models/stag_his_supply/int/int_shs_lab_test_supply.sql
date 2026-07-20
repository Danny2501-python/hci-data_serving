with smltm as (
    select
        id, lab_test_id as name, init_quantity as qty, uom_id, product_id as supply, notes, quantity as qty_used,
        location_id, medicament_type, sequence, create_uid, create_date, write_uid, write_date,
        picking_id, '' as explanation_supply, brand_etl
    from {{ ref('stg_shs_sh_medical_lab_test_material') }}
    where brand_etl <> 0
),
smlt as (
    select * from {{ ref('stg_shs_sh_medical_lab_test') }}
)

select
    'lab_test' as data_union, smltm.id, smltm.name, smltm.qty, smltm.uom_id, smltm.supply, smltm.notes, smltm.qty_used,
    smltm.location_id, smltm.medicament_type, smltm.sequence, smltm.create_uid, smltm.create_date, smltm.write_uid, smltm.write_date,
    smltm.picking_id, smltm.explanation_supply, smlt.id as form_id, smlt.name as form_name, smlt.date_done as services_date, smlt.patient,
    null::integer as service_id, smlt.walkin as walkinid,
    smlt.department as ward_id, smlt.perform_room as room_id, smlt.institution, 'Surgery'::character varying as department_type,
    smltm.brand_etl
from smltm
left join smlt on smlt.id = smltm.name and smlt.brand_etl = smltm.brand_etl
where smlt.state = 'Completed'
