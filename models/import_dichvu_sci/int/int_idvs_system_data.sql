select
            pp.default_code as "default_code cũ",
            pt."name" as "name",
            pp.type_product_crm,
            pc.code as "service_category/name",
            'base.' || rc."name" as "currency_id/id",
            smhcs.is_surgeries::text,
            case
                smhcs.surgery_type when 'major' then 'Đại phẫu'
                when 'minor' then 'Tiểu phẩu'
                else null
            end as surgery_type,
            case
                smhcs.anesthetist_type when 'te' then 'Gây tê'
                when 'tien_me' then 'Tiền mê'
                when 'me' then 'Gây mê'
                when 'tetaicho' then 'Tê tại chỗ'
                when 'boite' then 'Bôi tê'
                when 'tiemte' then 'Tiêm tê'
                when 'tetuysong' then 'Tê tủy sống'
                else smhcs.anesthetist_type
            end anesthetist_type,
            uu.id as "uom_id/id",
            uu."name" as "uom_id/name",
            uu1."name" as "uom_so_id/id",
            uu2."name" as "uom_po_id/id",
            smhcs.his_service_type,
            smhcs.level_of_difficult,
            smhcs.execution_time,
            smhcs.recovery_time,
            smhcs.warranty_period,
            smhcug."name" as "uom_guarantee/name",
            smhcs.note,
            smhcs.kpi_point,
            smhcs.kpi_point_num,
            smhcs.is_no_specialty::text,
            smhcs.is_no_phonecall::text,
            smhcs.is_input_num::text,
            smhcs.promotional_ceiling as "ceiling_discount_ids/ceiling_discount",
            smhcs.info as "hướng dẫn sau dịch vụ",
            case
                smhcs.allow_ctv
                when 'Yes' then 'Cho phép tính'
                when 'No' then 'Không tính'
                else null
            end as "tính hoa hồng ctv",
            pp.brand_etl
        from
            {{ ref('stg_idvs_product_product') }} pp
        left join {{ ref('stg_idvs_product_template') }} pt on
            pp.product_tmpl_id = pt.id and pp.brand_etl = pt.brand_etl
        left join {{ ref('stg_idvs_sh_medical_health_center_service') }} smhcs on
            pp.id = smhcs.product_id and smhcs.brand_etl = pp.brand_etl
        left join {{ ref('stg_idvs_sh_medical_health_center_service_category') }} smhcsc on
            smhcs.service_category = smhcsc.id and smhcs.brand_etl = smhcsc.brand_etl
        left join {{ ref('stg_idvs_product_category') }} pc on
            smhcsc.product_cat_id = pc.id and smhcsc.brand_etl = pc.brand_etl
        left join {{ ref('stg_idvs_res_currency') }} rc on
            rc.id = smhcs.currency_id and smhcs.brand_etl = rc.brand_etl
        left join {{ ref('stg_idvs_uom_uom') }} uu on
            uu.id = pt.uom_id and uu.brand_etl = pt.brand_etl
        left join {{ ref('stg_idvs_uom_uom') }} uu2 on
            uu2.id = pt.uom_po_id and pt.brand_etl = uu2.brand_etl
        left join {{ ref('stg_idvs_uom_uom') }} uu1 on
            uu1.id = pt.uom_so_id and uu1.brand_etl = pt.brand_etl
        left join {{ ref('stg_idvs_sh_medical_health_center_uom_guarantee') }} smhcug on
            smhcug.id = smhcs.uom_guarantee and smhcug.brand_etl = smhcs.brand_etl
