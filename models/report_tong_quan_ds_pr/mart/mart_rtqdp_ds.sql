with ecl2 as (
    select * from {{ ref('stg_rtqdp_crm_lead') }} cl where cl.brand_etl = 3
), 
cline as (
    select * from {{ ref('stg_rtqdp_crm_line') }} cline where cline.brand_etl = 3 
),
ao as (
    select 'Ao' as bang,
        0 as id_source, 
        date(gts."time") as "Ngay", 
        null "Booking", 
        null as dien_thoai, 
        null as loai_kh, 
        null :: integer as "ID", 
        null as "Phieu", 
        gts.kenh as "Nguon", 
        case when gts.nguon = 'Nguồn khác' then 'Khác' else gts.nguon end as "Nhom_nguon", 
        null as "DV/SP", 
        null as "service_code", 
        null "Loai_DV/SP", 
        null as "Nhom_DV", 
        gts."thương hiệu" as "Thuong_hieu", 
        gts.brand_id as brandid, 
        gts."chi nhánh" as "Chi_nhanh", 
        gts.company_id as chinhanhphanquyen_nu, 
        0 as "Thanh_toan", 
        0 as "Tong_tien", 
        null as "TT_DV/SP", 
        null as "Loai", 
        gts.kenh as kenh, 
        gts.id_kenh :: integer as ma_kenh, 
        case when gts.nguon = 'Nguồn khác' then 'Khác' else gts.nguon end as nguon_moi, 
        gts.id_nguon :: integer ma_nguon_moi, 
        null as loai_phau_thuat
    from {{ ref('stg_rtqdp_target_kangnam_chitieu') }} gts 
    where gts."time" >='20240101'
),
dv as (
    select 'DV' as bang,
        eus.id as id_source, 
        date(spt.payment_date + '07:00:00' :: interval) as "Ngay", 
        ecl2.name as "Booking", 
        ecl2.phone as dien_thoai, 
        ecl2.type_data_partner as loai_kh, 
        ecl.id as "ID", 
        spt.ma_phieu as "Phieu", 
        ss.org_source  as "Nguon", 
        ss.org_category_source as "Nhom_nguon", 
        sp.product  as "DV/SP", 
        sp.default_code as "service_code", 
        sp.his_service_type as "Loai_DV/SP", 
        sp.product_category as "Nhom_DV", 
        erb.name as "Thuong_hieu", 
        erb.id as brandid, 
        mrc.name as "Chi_nhanh", 
        mrc.id as chinhanhphanquyen, 
        (spt.payment / 1000) as "Thanh_toan", 
        ecl.total_received as "Tong_tien", 
        ecl.stage as "TT_DV/SP", 
        case when spt.ma_phieu like '%PDC%' then 'Transfer' else spt.ma_phieu end as "Loai", 
        ss.org_source as kenh, 
        ss.channel_id as ma_kenh, 
        ss.org_category_source as nguon_moi, 
        case 
            when ss.org_category_source = 'Marketing Digital' then 1 
            when ss.org_category_source = 'Marketing Offline' then 2 
            when ss.org_category_source = 'Marketing Location' then 3 
            when ss.org_category_source = 'Khác' then 4 
        end ma_nguon_moi,
        sp.surgery_type as loai_phau_thuat
    from (select * from {{ ref('stg_rtqdp_payment_transfer') }} spt where spt.brand_etl = 3) spt 
    left join ecl2 on spt.crm_id = ecl2.id 
    left join cline ecl on spt.clineid = ecl.id and spt.product_id = ecl.product_id 
    left join {{ ref('stg_rtqdp_m_res_company') }} mrc on spt.company_id = mrc.id and mrc.brand_etl = 3
    left join {{ ref('stg_rtqdp_res_brand') }} erb on mrc.brand_id = erb.id and erb.brand_etl = 3
    left join {{ ref('stg_rtqdp_utm_source') }} eus on ecl2.source_id = eus.id and eus.brand_etl = 3
    left join {{ ref('stg_rtqdp_products') }} sp on sp.pr_product_id = spt.product_id 
    left join {{ ref('stg_rtqdp_sources') }} ss on ss.old_id = ecl2.source_id and ss.brand_id = 3
    where spt.payment <> 0 
        and spt.payment_date >= '20250801' 
        and mrc.brand_id = 3
),
rp as (
    select * from ao 
    union all 
    select * from dv
)
select * from rp
