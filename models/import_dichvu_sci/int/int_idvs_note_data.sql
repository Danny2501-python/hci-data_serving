with data_after_update as (select * from {{ ref('int_idvs_data_after_update') }}),
system_data as (select * from {{ ref('int_idvs_system_data') }}),
update_id_old_code as (select * from {{ ref('int_idvs_update_id_old_code') }})

select
            td.*,
            case
                when exists (select 1 from system_data  a where a."default_code cũ" = oss."default_code cũ") and oss."default_code cũ" = oss."default_code mới" then 'Dịch vụ cũ' || td4.false_duplicate_product_id || td2.false_ins_id || oss.false_brand || td3."false_service_category/id"||td3."false_institution/id"||td3."false_service_department/id"||td3."false_service_room/id"||td3."false_exam_room/id"|| td3."false_categ_id/id"|| oss.false_kpi_point_num || td3."false_ctv"
                when not exists (select 1 from system_data a where a."default_code cũ" = oss."default_code mới") and oss."default_code cũ" = oss."default_code mới" then 'Dịch vụ mới' ||  td4.false_duplicate_product_id || oss.false_name || td3."false_service_category/id"||td3."false_institution/id"||td3."false_service_department/id"||td3."false_service_room/id"||td3."false_exam_room/id"|| td3."false_categ_id/id"
                || oss.false_service_category  || oss.false_currrency || oss.false_uomid || oss.false_type_service || oss.false_level || oss.false_kpi_point_num
                || oss.false_execution_time || oss.false_brand || td3."false_ctv" || td3.false_ceiling_discount_percent
                else 'Thay đổi default_code mới cho dịch vụ cũ'|| td4.false_duplicate_product_id || td2.false_ins_id || oss.false_name || td3."false_service_category/id"||td3."false_institution/id"||td3."false_service_department/id"||td3."false_service_room/id"||td3."false_exam_room/id"|| td3."false_categ_id/id"
                || oss.false_service_category || oss.false_currrency || oss.false_uomid || oss.false_type_service || oss.false_level || oss.false_kpi_point_num
                || oss.false_execution_time|| oss.false_brand || td3."false_ctv" || td3.false_ceiling_discount_percent
            end as data_status
        from
            data_after_update td
        left join (
            select
                p.stt,
                p."default_code cũ",
                p."default_code mới",
                p."ceiling_discount_ids/brand_id/id",
                case
                    when p."name" is null then ' | thiếu tên dịch vụ'
                    else ''
                end as false_name,
                case
                    when p."service_category/name" is null then ' | thiếu service_category/name'
                    else ''
                end as false_service_category,
                case
                    when p."currency_id/id" is null then ' | thiếu currency_id/id'
                    else ''
                end as false_currrency,
                case
                    when p."uom_id/name" is null then ' | thiếu uom_id/name'
                    else''
                end false_uomid,
                case
                    when p.his_service_type is null then ' | his_service_type'
                    else ''
                end false_type_service,
                case
                    when p.level_of_difficult is null then ' | thiếu level_of_difficult'
                    else ''
                end false_level,
                case
                    when p.execution_time is null then ' | thiếu execution_time'
                    else ''
                end false_execution_time,
                case
                    when kpi_point_num::numeric % 1 <> 0 then ' | kpi_point_num phải là số nguyên'
                    else ''
                end as false_kpi_point_num,
                case
                    when p."ceiling_discount_ids/brand_id/id" is null then ' | thiếu ceiling_discount_ids/brand_id/id'
                            when not exists (select 1 from (
        select
            c.id ,
            concat(d."module",'.',d.name) as brand_id,
        c."name"
        from
            (select * from {{ ref('stg_idvs_ir_model_data') }} a where a."model" = 'res.brand' and a.res_id not in (2, 5))d
        left join {{ ref('stg_idvs_res_brand') }} c on c.id = d.res_id and c.brand_etl = d.brand_etl
        ) tb where tb.brand_id = p."ceiling_discount_ids/brand_id/id") then ' | Sai ceiling_discount_ids/brand_id/id'
                    else ''
                end false_brand
            from
                update_id_old_code p) oss on td.stt = oss.stt
        left join (
            select
                l.stt,
                l."default_code mới",
                l.brand,
                case
                    when not exists (select 1 from {{ ref('stg_idvs_product_product') }} pp where l."default_code cũ" = pp."default_code" and  l.brand = pp.brand_etl) then ' | Không còn mã default_code cũ nữa'
                    else ''
                end as false_ins_id
            from
                update_id_old_code l) td2 on td.stt = td2.stt
        left join (
            select
                p.stt,
                p."default_code",
                p."ceiling_discount_ids/brand_id/id",
                case
                    when p."service_category/id" is null then ' | thiếu service_category/id'
                    else ''
                end as "false_service_category/id",
                case
                    when p."institution/id" is null then ' | thiếu institution/id'
                    else ''
                end as "false_institution/id",
                case
                    when p."service_department/id" is null then ' | thiếu service_department/id'
                    else ''
                end as "false_service_department/id",
                case
                    when p."service_room/id" is null then ' | thiếu service_room/id'
                    else ''
                end as "false_service_room/id",
                case
                    when p."exam_room/id" is null then ' | thiếu exam_room/id'
                    else ''
                end as "false_exam_room/id",
                case
                    when p."categ_id/id" is null then ' | thiếu categ_id/id'
                    else ''
                end as "false_categ_id/id",
                case
                    when p."tính hoa hồng ctv" is null then ' | tính hoa hồng ctv không được để trống'
                    when p."tính hoa hồng ctv" not in ('Cho phép tính', 'Không tính') then ' | Sai tính hoa hồng ctv ("Cho phép tính", "Không tính")'
                    else ''
                end as "false_ctv",
                case
                    when p."ceiling_discount_ids/ceiling_discount" > 100 then ' | Thiếu % vào cột "ceiling_discount_ids/ceiling_discount"'
                    else ''
                end as "false_ceiling_discount_percent"
            from
                data_after_update p) td3 on td3.stt = td.stt
            left join (with duplicate_products as (
                    select
                        "default_code mới",
                        json_agg(stt) as stt_list
                    from
                        {{ ref('stg_idvs_import_danhmuc_dichvu_sci') }} ibgcts
                    group by
                        "default_code mới"
                    having count(*) > 1
                    )
                    select
                        idds.stt,
                        idds."default_code mới",
                        CASE
                            WHEN dp."default_code mới" IS NOT NULL THEN ' | default_code đang bị trùng stt'|| dp.stt_list
                            ELSE ''
                                END AS false_duplicate_product_id
                            FROM
                                {{ ref('stg_idvs_import_danhmuc_dichvu_sci') }} idds
                            LEFT JOIN
                                duplicate_products dp ON idds.stt = ANY (array(select json_array_elements_text(dp.stt_list)::int))) td4
                    on td.stt = td4.stt
        order by  td.stt
