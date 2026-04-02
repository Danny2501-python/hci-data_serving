with cte_payment as (
    select
        std_1.*
    from {{ source('master_data', 'stag_payment_transfer') }} std_1
    where
        std_1.brand_etl = 1 and nullif(std_1.payment_date::text, '')::date >= '20250801'
),

a as (
    select
        std.id as key,
        sp.product as "DV/SP",
        cl3.overseas_vietnamese as vk,
        case
            when ss.source::text ~~ '%Facebook%'::text then 'FB'::text
            when ss.source::text ~~ '%Seo%'::text then 'Web'::text
            when ss.source::text ~~ '%Google%'::text then 'Web'::text
            when ss.source::text ~~ '%Hotline%'::text then 'Web'::text
            else 'Khác'::text
        end as kenh,
        std.payment_date as date_time,
        mrc.name as chi_nhanh,
        std.payment as doanh_so,
        sp.product_category as nhom_dv_qc,
        ss.source as nguon_ds,
        ss.category_source as nhom_nguon,
        case
            when rcs.name::text = 'Thành phố Hồ Chí Minh'::text then 'SÀI GÒN'::character varying
            when rcs.name::text = 'Thành phố Hà Nội'::text then 'Hà Nội'::character varying
            when rcs.name is null then 'KXĐ'::character varying
            when rcs.code::text !~~ '%VN-%'::text then 'VIỆT KIỀU'::character varying
            else rcs.name
        end as local_k,
        rc.name as quoc_gia,
        cl3.ticket_id
    from cte_payment std
    left join {{ source('erp', 'crm_lead') }} cl3 on
        std.crm_id = cl3.id and std.brand_etl = cl3.brand_etl
    left join {{ source('master_data', 'res_country_state') }} rcs on
        rcs.id = cl3.state_id and rcs.brand_etl = 1
    left join {{ source('master_data', 'res_country') }} rc on
        rc.id = cl3.country_id and rc.brand_etl = 1
    left join {{ source('master_data', 'view_stag_products') }} sp on
        sp.product_id = std.product_id and sp.brand_etl = std.brand_etl
    left join {{ source('master_data', 'stag_sources') }} ss on
        ss.old_id = cl3.source_id::double precision
    left join {{ source('erp', 'm_res_company') }} mrc on
        mrc.id = std.company_id and mrc.brand_etl = 1
),

b as (
    select
        a.vk,
        a."DV/SP",
        a.nguon_ds as "Nguon",
        a.nhom_nguon as "Nhom_nguon",
        case
            when a.vk::text = 'marketing'::text then 'VIỆT KIỀU'::character varying
            when a.chi_nhanh::text = 'VIỆN THẨM MỸ KANGNAM BẠCH MAI'::text
                and (a.vk::text <> all (array['marketing'::character varying::text, 'mkt_oversea'::character varying::text])) then 'BỆNH VIỆN KANGNAM HÀ NỘI'::character varying
            when a.chi_nhanh::text = 'BỆNH VIỆN KANGNAM NGUYỄN TRÃI'::text
                and (a.vk::text <> all (array['marketing'::character varying::text, 'mkt_oversea'::character varying::text])) then 'BỆNH VIỆN KANGNAM SÀI GÒN'::character varying
            when a.chi_nhanh::text = 'BỆNH VIỆN KANGNAM SÀI GÒN'::text
                and (a.vk::text <> all (array['marketing'::character varying::text, 'mkt_oversea'::character varying::text])) then 'BỆNH VIỆN KANGNAM SÀI GÒN'::character varying
            when a.vk::text = 'mkt_oversea'::text then 'QUỐC TẾ'::character varying
            else a.chi_nhanh
        end as chi_nhanh_cp_locate,
        a.nhom_dv_qc as nhom_dv,
        a.date_time as ngay,
        a.kenh,
        a.doanh_so,
        a.local_k,
        a.quoc_gia,
        a.key,
        a.ticket_id
    from a
)

select
    b.vk,
    b."DV/SP",
    b."Nguon",
    b."Nhom_nguon",
    b.kenh as channel,
    b.ngay as date_ds,
    b.nhom_dv,
    b.chi_nhanh_cp_locate as location,
    b.local_k,
    b.quoc_gia,
    b.doanh_so::text as "Metric",
    'DS'::text as type_data,
    b.ticket_id
from b

