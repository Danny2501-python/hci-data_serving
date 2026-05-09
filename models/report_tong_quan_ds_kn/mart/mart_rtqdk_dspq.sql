{{ config(alias='mart_dspq') }}

-- Logic 100% từ dspq.sql
-- ecl2: join thẳng vào crm_lead (không qua CTE — giữ đúng behavior gốc)
-- ecl : crm_line UNION crm_line_product (dùng int_rtqdk_cline)

with ecl as (
    select * from {{ ref('int_rtqdk_cline') }}
),

dv as (
    select
        'DV' as bang,
        ecl2.source_id as id_source,
        date(spt.payment_date + '07:00:00'::interval) as "Ngay",
        ecl2.name as "Booking",
        ecl2.phone as dien_thoai,
        ecl2.type_data_partner as loai_kh,
        ecl.id as "ID",
        spt.ma_phieu as "Phieu",
        ss."source" as "Nguon",
        ss.category_source as "Nhom_nguon",
        sp.product as "DV/SP",
        sp.default_code as "service_code",
        case
            when sp.product_category = 'SAN PHAM' then 'Sản Phẩm'
            else sp.his_service_type
        end as "Loai_DV/SP",
        sp.product_category as "Nhom_DV",
        erb.name as "Thuong_hieu",
        erb.id as brandid,
        mrc.name as "Chi_nhanh",
        mrc.id as chinhanhphanquyen_nu,
        (spt.payment / 1000) as "Thanh_toan",
        ecl.total_received as "Tong_tien",
        ecl.stage as "TT_DV/SP",
        case when spt.ma_phieu like '%PDC%' then 'Transfer' else spt.ma_phieu end as "Loai",
        ss.channel as kenh,
        ss.channel_id as ma_kenh,
        ss.category_channel as nguon_moi,
        case
            when ss.category_channel = 'Marketing Digital' then 1
            when ss.category_channel = 'Marketing Offline' then 2
            when ss.category_channel = 'Marketing Location' then 3
            when ss.category_channel = 'Khác' then 4
        end as ma_nguon_moi,
        sp.surgery_type as loai_phau_thuat
    from {{ ref('stg_rtqdk_payment_transfer') }} spt
    left join {{ ref('stg_rtqdk_crm_lead') }} ecl2
        on spt.crm_id = ecl2.id and spt.brand_etl = ecl2.brand_etl
    left join ecl
        on spt.clineid = ecl.id and spt.brand_etl = ecl.brand_etl
    left join {{ ref('stg_rtqdk_m_res_company') }} mrc
        on spt.company_id = mrc.id and mrc.brand_etl = 1
    left join {{ ref('stg_rtqdk_res_brand') }} erb
        on mrc.brand_id = erb.id and erb.brand_etl = 1
    left join {{ ref('stg_rtqdk_products') }} sp
        on sp.product_id = spt.product_id and sp.brand_etl = spt.brand_etl
    left join {{ ref('stg_rtqdk_sources') }} ss
        on ss.old_id = ecl2.source_id and ss.brand_id = 1
    where spt.brand_etl in (0, 1)
      and ecl2.id is not null
      and spt.payment_date >= '20250801'
      and mrc.brand_id = 1
)

select * from dv

