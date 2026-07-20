with s as (
    select * from {{ ref('int_shs_supplies_union') }}
),
smm as (
    select * from {{ ref('stg_shs_sh_medical_medicines') }}
),
uu as (
    select * from {{ ref('stg_shs_uom_uom') }}
),
smarw as (
    select * from {{ ref('stg_shs_sh_medical_appointment_register_walkin') }}
),
smhc as (
    select * from {{ ref('stg_shs_sh_medical_health_center') }}
),
sl as (
    select * from {{ ref('stg_shs_stock_location') }}
),
slw as (
    select * from {{ ref('stg_shs_stock_location') }}
),
cl as (
    select * from {{ ref('stg_shs_crm_lead') }}
),
smhcs as (
    select * from {{ ref('stg_shs_sh_medical_health_center_service') }}
),
sp3 as (
    select * from {{ ref('stg_shs_stock_picking') }}
)

select
    s.brand_etl, s.data_union, s.id form_supply_id,
    row_number() over (partition by s.brand_etl, s.data_union, s.id) as rn_form_supply,
    s.name form_id, cl.id crm_id, cl.name booking, smarw.name walkin, cl.code_customer, cl.contact_name, s.form_name, s.services_date,
    case when smm.medicament_type = 'Medicine' then 'THUỐC' else 'VẬT TƯ' end supply_category,
    smm.name_use supply, uu.name uom, s.uom_id, s.qty_used, s.qty, s.explanation_supply, s.notes, sl.name "location",
    slw.name location_department, s.department_type, smhc.company_name company,
    s.service_id, smhcs.product_id, s.supply supply_id, smm.product_id supply_product_id,
    s.patient, s.walkinid, s.ward_id, s.room_id, s.location_id, s.picking_id, sp3."name" picking, smhc.his_company company_id,
    s.data_union || '-' || coalesce(s.id::text, '0') || '-' || coalesce(smhcs.product_id::text, '0')
        || '-' || coalesce(smm.product_id::text, '0') || '-' || coalesce(s.brand_etl::text, '0') as id_etl
from s
left join smm on s.supply = smm.id and smm.brand_etl = s.brand_etl
left join uu on s.uom_id = uu.id and s.brand_etl = uu.brand_etl
left join smarw on s.walkinid = smarw.id and smarw.brand_etl = s.brand_etl
left join smhc on s.institution = smhc.id and smhc.brand_etl = s.brand_etl
left join sl on s.location_id = sl.id and sl.brand_etl = s.brand_etl
left join slw on sl.location_id = slw.id and slw.brand_etl = sl.brand_etl
left join cl on smarw.booking_id = cl.id and smarw.brand_etl = cl.brand_etl
left join smhcs on s.service_id = smhcs.id and smhcs.brand_etl = s.brand_etl
left join sp3 on sp3.id = s.picking_id and sp3.brand_etl = s.brand_etl
