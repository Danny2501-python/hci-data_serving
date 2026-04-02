with base as (
    select
        cgk.campaign,
        cgk.account,
        cgk.cost,
        nullif(cgk.date::text, '')::date as ngay,
        split_part(cgk.campaign, '_', 1) as dv,
        split_part(cgk.campaign, '_', 2) as cn1,
        split_part(cgk.campaign, '_', 3) as cn2,
        split_part(cgk.campaign, ' - ', 1) as cn_dash
    from {{ source('ads_raw_data', 'cp_google_kangnam') }} cgk
    where
        cgk.account is not null
        and nullif(cgk.date::text, '')::date >= DATE '2025-08-01'
),

a as (
    select
        campaign,
        'Web' as channel,
        dv as nhom_dv,
        case
            when cn1 in ('VIỆT KIỀU', 'Viet') then 'VIỆT KIỀU'
            when campaign = 'XLKH' then 'BỆNH VIỆN KANGNAM SÀI GÒN'
            when cn1 = 'HN' then 'BỆNH VIỆN KANGNAM HÀ NỘI'
            when cn1 = 'HCM' then 'BỆNH VIỆN KANGNAM SÀI GÒN'
            when cn_dash = 'HCM' then 'BỆNH VIỆN KANGNAM SÀI GÒN'
            when cn1 || ' ' || cn2 = 'Can Tho' then 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'
            when cn1 || ' ' || cn2 = 'Da Nang' then 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'
            when cn1 || ' ' || cn2 = 'Hai Phong' then 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'
            when cn1 || ' ' || cn2 = 'Nghe An' then 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'
            when cn1 || ' ' || cn2 = 'Quoc Te' then 'QUỐC TẾ'
        end as chi_nhanh,
        ngay,
        (cost::float8 * 23500)::text as chi_phi,
        account
    from
        base
)

select
    a.campaign,
    case
        when a.chi_nhanh ilike '%VIỆT KIỀU%' then 'VIỆT KIỀU'
        when a.chi_nhanh ilike '%QUỐC TẾ%' then 'QUỐC TẾ'
        else 'no'
    end as vk,
    'DV' as dv,
    'GG' as "Nguon",
    'GG' as "Nhom_nguon",
    a.channel,
    a.ngay,
    case
        when a.nhom_dv = '88888' then 'VIỆT KIỀU'
        when a.nhom_dv = '99999' then 'THƯƠNG HIỆU'
        when a.nhom_dv = 'XLKH' then 'THƯƠNG HIỆU'
        else pc.name
    end as nhom_dv,
    a.chi_nhanh,
    case
        when a.chi_nhanh = 'BỆNH VIỆN KANGNAM SÀI GÒN' then 'SÀI GÒN'
        when a.chi_nhanh = 'BỆNH VIỆN KANGNAM HÀ NỘI' then 'HÀ NỘI'
        when a.chi_nhanh = 'VIỆN THẨM MỸ KANGNAM CẦN THƠ' then 'Thành phố Cần Thơ'
        when a.chi_nhanh = 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG' then 'Thành phố Đà Nẵng'
        when a.chi_nhanh = 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG' then 'Thành phố Hải Phòng'
        when a.chi_nhanh = 'VIỆN THẨM MỸ KANGNAM NGHỆ AN' then 'Tỉnh Nghệ An'
        else a.chi_nhanh
    end as local_k,
    case
        when a.chi_nhanh = 'VIỆT KIỀU' then 'VIỆT KIỀU'
        when a.chi_nhanh = 'QUỐC TẾ' then 'QUỐC TẾ'
        else 'Việt Nam'
    end as quoc_gia,
    a.chi_phi as "Metric",
    a.account,
    case
        when a.account <> 'Thương hiệu - Brand' then 'Google_cd'
        else 'Google_th'
    end as data_type,
    0 as ticket_id
from a
left join {{ source('master_data', 'product_category') }} pc on pc.id::text = a.nhom_dv and pc.brand_etl = 1


