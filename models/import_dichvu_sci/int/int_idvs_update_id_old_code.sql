with data_processing as (select * from {{ ref('int_idvs_data_processing') }}),
system_data as (select * from {{ ref('int_idvs_system_data') }})

select
            ise.stt,
            c.service_id as id,
            ise."default_code cũ",
            ise."default_code mới",
            ise.name,
            case
                when (SELECT EXISTS (SELECT 1 FROM {{ ref('stg_idvs_product_category') }} pc WHERE pc.code = ise."service_category/name")) then pc."name"
                when null then null
                else ise."service_category/name"
            end "service_category/name",
            f.category_service_id as "service_category/id",
            inst_id.id as "institution/id",
            s_department_id.id as "service_department/id",
            s_room_id.id as "service_room/id",
            e_room_id.id as "exam_room/id",
            cate_id.id as "categ_id/id",
            'service_crm' as type_product_crm,
            ise.list_price,
            ise.price_min,
            ise."currency_id/id",
            ise.is_surgeries,
            upper(substr(lower(ise.surgery_type) , 1, 1)) || substr(lower(ise.surgery_type),2) as "surgery_type",
            upper(substr(lower(ise.anesthetist_type) , 1, 1)) || substr(lower(ise.anesthetist_type),2) as "anesthetist_type",
            u_id.id as "uom_id/id",
            ise."uom_id/name",
            us_id.id as "uom_so_id/id",
            up_id.id as "uom_po_id/id",
            ise.his_service_type,
            ise.level_of_difficult,
            ise.execution_time,
            ise.recovery_time,
            ise.warranty_period,
            ise."uom_guarantee/name",
            ise."note",
            ise.kpi_point,
            ise.kpi_point_num,
            ise.is_no_specialty,
            ise.is_no_phonecall,
            ise.is_input_num,
            case
                when ise."lab_type_ids/id" is null then lab_id.id
                else ise."lab_type_ids/id"
            end as "lab_type_ids/id" ,
            case
                when ise."imaging_type_ids/id" is null then imag_id.id
                else ise."imaging_type_ids/id"
            end as "imaging_type_ids/id" ,
            ise."ceiling_discount_ids/brand_id/id",
            ise."ceiling_discount_ids/ceiling_discount"::numeric(20,0),
            ise."hướng dẫn sau dịch vụ",
            ise."tính hoa hồng ctv",
            ise.ghi_chu,
            ise.brand,
            case
                when exists (select 1 from system_data a where a."default_code cũ" = ise."default_code mới") then false
                else true
            end is_new
        from
            data_processing ise
        left join {{ ref('stg_idvs_product_category') }} pc on pc.code = ise."service_category/name" and ise.brand = pc.brand_etl
        -- id  cho dịch vụ
        left join (select concat(imd."module" ,'.',imd."name") as service_id,pp.default_code, imd.brand_etl from (select * from {{ ref('stg_idvs_ir_model_data') }} imd where imd.model ='sh.medical.health.center.service') imd
        join {{ ref('stg_idvs_sh_medical_health_center_service') }} smhcs on smhcs.id = imd.res_id and smhcs.brand_etl = imd.brand_etl
        left join {{ ref('stg_idvs_product_product') }} pp on pp.id = smhcs.product_id and smhcs.brand_etl = pp.brand_etl) c on c.default_code = ise."default_code cũ" and c.brand_etl = ise.brand
        -- category_service_id
        left join
        (select distinct smhcsc.brand_etl, concat(imd."module",'.',imd."name") as category_service_id, pc.code
        from {{ ref('stg_idvs_sh_medical_health_center_service_category') }} smhcsc
        join {{ ref('stg_idvs_product_category') }} pc on pc.id = smhcsc.product_cat_id and pc.brand_etl = smhcsc.brand_etl
        join {{ ref('stg_idvs_ir_model_data') }} imd on imd.res_id = smhcsc.id and imd.brand_etl = smhcsc.brand_etl
        where imd.model = 'sh.medical.health.center.service.category' ) f on  f.code = ise."service_category/name" and f.brand_etl= ise.brand
        -- institution/id
        left join(with b as (
select concat(imd."module", '.', imd."name") as id, smhc.brand_etl, smhc.id as res_id from {{ ref('stg_idvs_sh_medical_health_center') }} smhc
left join {{ ref('stg_idvs_ir_model_data') }} imd on imd.res_id = smhc.id and imd.brand_etl = smhc.brand_etl
where imd.model = 'sh.medical.health.center'
), a as (
select smhc.*, pp.default_code  from b smhc
join {{ ref('stg_idvs_smhc_service_rel') }} smhcsmhcsr on smhcsmhcsr.sh_medical_health_center_id = smhc.res_id and smhcsmhcsr.brand_etl = smhc.brand_etl
join {{ ref('stg_idvs_sh_medical_health_center_service') }} smhcs on smhcsmhcsr.sh_medical_health_center_service_id = smhcs.id and smhcsmhcsr.brand_etl = smhcs.brand_etl
join {{ ref('stg_idvs_product_product') }} pp on pp.id = smhcs.product_id and pp.brand_etl = smhcs.brand_etl
where exists (select 1 from {{ ref('stg_idvs_import_danhmuc_dichvu_sci') }} idds where pp.default_code = idds.default_code)
)
select
             a.brand_etl, a.default_code,string_agg(distinct a.id,',') as id
        from a
        group by a. brand_etl, a.default_code) as inst_id on inst_id.default_code = ise."default_code cũ" and inst_id.brand_etl = ise.brand
        -- service_department/id
        left join (with b as (
select concat(imd."module", '.', imd."name") as id, smhc.brand_etl, smhc.id as res_id from {{ ref('stg_idvs_sh_medical_health_center_ward') }} smhc
left join {{ ref('stg_idvs_ir_model_data') }} imd on imd.res_id = smhc.id and imd.brand_etl = smhc.brand_etl
where imd.model = 'sh.medical.health.center.ward'
), a as (
select smhcw.*, pp.default_code  from b smhcw
join {{ ref('stg_idvs_service_departments_rel') }} sdr on sdr.sh_medical_health_center_ward_id = smhcw.res_id and sdr.brand_etl = smhcw.brand_etl
join {{ ref('stg_idvs_sh_medical_health_center_service') }} smhcs on sdr.sh_medical_health_center_service_id = smhcs.id and sdr.brand_etl = smhcs.brand_etl
join {{ ref('stg_idvs_product_product') }} pp on pp.id = smhcs.product_id and pp.brand_etl = smhcs.brand_etl
where exists (select 1 from {{ ref('stg_idvs_import_danhmuc_dichvu_sci') }} idds where pp.default_code = idds.default_code))
select
             a.brand_etl, a.default_code,string_agg(distinct a.id,',') as id
        from a
        group by a. brand_etl, a.default_code
) as s_department_id on s_department_id.default_code = ise."default_code cũ"  and s_department_id.brand_etl = ise.brand
        -- service_room/id
        left join
        (with b as (
select concat(imd."module", '.', imd."name") as id, smhc.brand_etl, smhc.id as res_id from {{ ref('stg_idvs_sh_medical_health_center_ot') }} smhc
left join {{ ref('stg_idvs_ir_model_data') }} imd on imd.res_id = smhc.id and imd.brand_etl = smhc.brand_etl
where imd.model = 'sh.medical.health.center.ot'
), a as (
select smhco.*, pp.default_code  from b smhco
join {{ ref('stg_idvs_service_rooms_rel') }} srr on srr.sh_medical_health_center_ot_id = smhco.res_id and srr.brand_etl = smhco.brand_etl
join {{ ref('stg_idvs_sh_medical_health_center_service') }} smhcs on srr.sh_medical_health_center_service_id = smhcs.id and srr.brand_etl = smhcs.brand_etl
join {{ ref('stg_idvs_product_product') }} pp on pp.id = smhcs.product_id and pp.brand_etl = smhcs.brand_etl
where exists (select 1 from {{ ref('stg_idvs_import_danhmuc_dichvu_sci') }} idds where pp.default_code = idds.default_code)
)
select
             a.brand_etl, a.default_code,string_agg(distinct a.id,',') as id
        from a
        group by a. brand_etl, a.default_code
) as s_room_id on s_room_id.default_code = ise."default_code cũ" and s_room_id.brand_etl = ise.brand
        -- exam_room/id
        left join (
with b as (
select concat(imd."module", '.', imd."name") as id, smhc.brand_etl, smhc.id as res_id from {{ ref('stg_idvs_sh_medical_health_center_ot') }} smhc
left join {{ ref('stg_idvs_ir_model_data') }} imd on imd.res_id = smhc.id and imd.brand_etl = smhc.brand_etl
where imd.model = 'sh.medical.health.center.ot'
), a as (
select smhco.*, pp.default_code  from b smhco
join {{ ref('stg_idvs_exam_rooms_rel') }} err on err.sh_medical_health_center_ot_id = smhco.res_id  and err.brand_etl = smhco.brand_etl
join {{ ref('stg_idvs_sh_medical_health_center_service') }} smhcs on err.sh_medical_health_center_service_id = smhcs.id and err.brand_etl = smhcs.brand_etl
join {{ ref('stg_idvs_product_product') }} pp on pp.id = smhcs.product_id and pp.brand_etl = smhcs.brand_etl
where exists (select 1 from {{ ref('stg_idvs_import_danhmuc_dichvu_sci') }} idds where pp.default_code = idds.default_code)
)
select
             a.brand_etl, a.default_code,string_agg(distinct a.id,',') as id
        from a
        group by a. brand_etl, a.default_code
) as e_room_id on e_room_id.default_code = ise."default_code cũ" and e_room_id.brand_etl = ise.brand
        -- categ_id/id
        join lateral (select concat(imd."module", '.', imd."name") AS id, imd.brand_etl from {{ ref('stg_idvs_ir_model_data') }} imd where imd.model = 'product.category' and imd.res_id = 10 and imd.brand_etl = ise.brand) as cate_id on true
        -- uom_id/id
        left join (
        select concat(imd."module", '.', imd."name") as id, uu.name, imd.brand_etl from {{ ref('stg_idvs_ir_model_data') }} imd
        join {{ ref('stg_idvs_uom_uom') }} uu on imd.res_id = uu.id and imd.brand_etl = uu.brand_etl
        where imd.model = 'uom.uom'
        )as u_id on upper(trim(ise."uom_id/name")) = upper(u_id."name") and ise.brand = u_id.brand_etl
        -- uom_so_id/id
        left join (
        select concat(imd."module", '.', imd."name") as id, uu.name, imd.brand_etl from {{ ref('stg_idvs_ir_model_data') }} imd
        join {{ ref('stg_idvs_uom_uom') }} uu on imd.res_id = uu.id and imd.brand_etl = uu.brand_etl
        where imd.model = 'uom.uom'
        )as us_id on upper(trim(ise."uom_so_id/id")) = upper(us_id."name") and ise.brand = us_id.brand_etl
        -- uom_po_id/id
        left join (
        select concat(imd."module", '.', imd."name") as id, uu.name, imd.brand_etl from {{ ref('stg_idvs_ir_model_data') }} imd
        join {{ ref('stg_idvs_uom_uom') }} uu on imd.res_id = uu.id  and imd.brand_etl = uu.brand_etl
        where imd.model = 'uom.uom'
        )as up_id on upper(trim(ise."uom_po_id/id")) = upper(up_id."name") and ise.brand = up_id.brand_etl
        -- lab_type_ids/id
        left join (
        with d as (
        select
        concat(imd."module", '.', imd."name") as id, pp.default_code, imd.brand_etl
        from {{ ref('stg_idvs_ir_model_data') }} imd
        join {{ ref('stg_idvs_sh_medical_labtest_types') }} smlt  on smlt.id = imd.res_id and smlt.brand_etl = imd.brand_etl
        join {{ ref('stg_idvs_sh_medical_services_labtest_types_rel') }} smsltr on smsltr.labtest_type_id = smlt.id and smsltr.brand_etl = smlt.brand_etl
        join {{ ref('stg_idvs_sh_medical_health_center_service') }} smhcs on smhcs.id = smsltr.service_id and smhcs.brand_etl = smsltr.brand_etl
        join {{ ref('stg_idvs_product_product') }} pp on pp.id = smhcs.product_id and pp.brand_etl = smhcs.brand_etl
            where imd.model = 'sh.medical.labtest.types')
        select brand_etl, d.default_code, string_agg(d.id,',') as id  from d group by brand_etl, d.default_code) as lab_id on lab_id.default_code = ise."default_code cũ" and lab_id.brand_etl = ise.brand
        -- imaging_type_ids/id
        left join (
        with a as (
        select
        concat(imd."module", '.', imd."name") as id, pp.default_code, pp.brand_etl
        from {{ ref('stg_idvs_ir_model_data') }} imd
        join {{ ref('stg_idvs_sh_medical_imaging_test_type') }} smitt  on smitt.id = imd.res_id and smitt.brand_etl = imd.brand_etl
        join {{ ref('stg_idvs_sh_medical_services_imaging_test_types_rel') }} smsittr on smsittr.imaging_type_id  = smitt.id and smsittr.brand_etl  = smitt.brand_etl
        join {{ ref('stg_idvs_sh_medical_health_center_service') }} smhcs on smhcs.id = smsittr.service_id and smhcs.brand_etl = smsittr.brand_etl
        join {{ ref('stg_idvs_product_product') }} pp on pp.id = smhcs.product_id and pp.brand_etl = smhcs.brand_etl
            where imd.model = 'sh.medical.imaging.test.type' )
        select brand_etl, a.default_code,string_agg(a.id, ',') as id  from a group by brand_etl, a.default_code) as imag_id on imag_id.default_code = ise."default_code cũ" and  imag_id.brand_etl = ise.brand
        order by  ise.stt
