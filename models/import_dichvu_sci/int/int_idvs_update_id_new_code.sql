with update_id_old_code as (select * from {{ ref('int_idvs_update_id_old_code') }})

select
            oss.stt,
            case
                when oss.id is null and oss."default_code cũ" = oss."default_code mới"  then '__import__.SERVICE_' || oss. "default_code mới"
                else oss.id
            end as id,
            oss."default_code mới" as default_code,
            oss.name,
            oss."service_category/name",
            oss."service_category/id",
            case
                when oss.is_new is false then oss."institution/id"
                else ins_id.institution_id
            end as "institution/id",
            case
                when oss.is_new is false then oss."service_department/id"
                else sv_depart.id
            end as "service_department/id",
            case
                when oss.is_new is false then oss."service_room/id"
                else ser_room.id
            end as "service_room/id",
            case
                when oss.is_new is false then oss."exam_room/id"
                else exam_room.id
            end as "exam_room/id",
            oss."categ_id/id",
            oss.type_product_crm,
            oss.list_price,
            oss.price_min,
            oss."currency_id/id",
            oss.is_surgeries,
            oss."surgery_type",
            oss."anesthetist_type",
            oss."uom_id/id",
            oss."uom_id/name",
            oss."uom_so_id/id",
            oss."uom_po_id/id",
            oss.his_service_type,
            oss.level_of_difficult,
            oss.execution_time,
            oss.recovery_time,
            oss.warranty_period,
            oss."uom_guarantee/name",
            oss."note",
            oss.kpi_point,
            oss.kpi_point_num,
            oss.is_no_specialty,
            oss.is_no_phonecall,
            oss.is_input_num,
            oss."lab_type_ids/id",
            oss."imaging_type_ids/id",
            oss."ceiling_discount_ids/brand_id/id",
            oss."ceiling_discount_ids/ceiling_discount"::numeric(20,0),
            oss."hướng dẫn sau dịch vụ",
            oss."tính hoa hồng ctv",
            oss.ghi_chu,
            oss.brand
        from
            update_id_old_code oss
        -- institution/id cho default_code mới
        left join (with a as (
        select smhc.id ,smhc.brand_etl,concat(imd."module",'.',imd."name") as inst_id, smhcw."type" from {{ ref('stg_idvs_ir_model_data') }} imd
        join {{ ref('stg_idvs_sh_medical_health_center') }} smhc on smhc.id = imd.res_id and smhc.brand_etl = imd.brand_etl
        join {{ ref('stg_idvs_sh_medical_health_center_ward') }} smhcw on smhc.id = smhcw.institution and smhc.brand_etl = smhcw.brand_etl
        where imd.model = 'sh.medical.health.center'
        )
        select a.brand_etl, "type", string_agg(a.inst_id, ',') as institution_id   from a group by a.brand_etl, "type") ins_id on ins_id.brand_etl = oss.brand and ins_id."type" = oss.his_service_type
        -- "service_department/id" cho default_code mới
        left join(with a as (
        select distinct
            concat(imd."module", '.', imd."name") as id, smhc.brand_etl, smhcw."type"
            from {{ ref('stg_idvs_ir_model_data') }} imd
            join {{ ref('stg_idvs_sh_medical_health_center_ward') }} smhcw on imd.res_id = smhcw.id and imd.brand_etl = smhcw.brand_etl
            join {{ ref('stg_idvs_sh_medical_health_center') }} smhc on smhc.id = smhcw.institution and smhc.brand_etl = smhcw.brand_etl
            where
                imd.model = 'sh.medical.health.center.ward'
                and imd."name" not ilike '%k_hcm_bhtq%'
                and smhc.brand <> 2
        )
        select
             a.brand_etl, a."type",string_agg(distinct a.id,',') as id
        from a
        group by a.brand_etl, a."type"
        ) sv_depart on sv_depart."type" = oss.his_service_type and sv_depart.brand_etl = oss.brand
        -- "service_room/id" cho default_code mới
        left join (with a as (
        select distinct
            concat(imd."module", '.', imd."name") as id,
            case
                when smhco.room_type ilike '%surgery%' then 'Surgery'
                else smhco.room_type
            end as room_type,
            smhc.brand_etl
            from {{ ref('stg_idvs_ir_model_data') }} imd
            join {{ ref('stg_idvs_sh_medical_health_center_ot') }} smhco on imd.res_id = smhco.id and imd.brand_etl = smhco.brand_etl
            join {{ ref('stg_idvs_sh_medical_health_center') }} smhc on smhc.id = smhco.institution and smhc.brand_etl = smhco.brand_etl
            where
                imd.model = 'sh.medical.health.center.ot'
                and imd."name" not ilike '%k_hcm_bhtq%'
                and smhco.active is true
                and smhco.room_type is not null
                and smhc.brand <> 2
        )
        select
             brand_etl, room_type, string_agg(distinct a.id,',') as id
        from a
        group by brand_etl, a.room_type) ser_room on ser_room.room_type = oss.his_service_type and ser_room.brand_etl = oss.brand
        -- "exam_room/id" cho default_code mới
        left join (with b as (
select distinct smhco.id, smhcs.his_service_type, smhco.brand_etl, smhco."name" from {{ ref('stg_idvs_sh_medical_health_center_ot') }} smhco
left join {{ ref('stg_idvs_sh_medical_health_center') }} smhc on smhc.id = smhco.institution and smhc.brand_etl = smhco.brand_etl
left join {{ ref('stg_idvs_sh_medical_health_center_ward') }} smhcw on smhcw.id = smhco.department and smhcw.brand_etl = smhco.brand_etl
left join {{ ref('stg_idvs_exam_rooms_rel') }} err on err.sh_medical_health_center_ot_id = smhco.id and err.brand_etl = smhco.brand_etl
left join {{ ref('stg_idvs_sh_medical_health_center_service') }} smhcs on err.sh_medical_health_center_service_id = smhcs.id and err.brand_etl = smhcs.brand_etl
where smhco.active is true
and (smhcw."type" = 'Examination' or smhco.room_type = 'Examination')
and smhc.brand <> 2
), a as (
select concat(imd."module", '.', imd."name") as id,smhco.his_service_type,smhco.brand_etl    from b  smhco
join {{ ref('stg_idvs_ir_model_data') }} imd on imd.res_id = smhco.id and imd.brand_etl = smhco.brand_etl
            where imd.model = 'sh.medical.health.center.ot'
                and imd."name" not ilike '%k_hcm_bhtq%')
        select
             a.brand_etl, a.his_service_type,string_agg(distinct a.id,',') as id
        from a
        group by  a.brand_etl, a.his_service_type) exam_room on exam_room.brand_etl = oss.brand and exam_room.his_service_type = oss.his_service_type
        order by  oss.stt
