
with a as (
    select
        'Facebook' as "Nguon",
        'Chi_phi' as bang,
        cfaai."date" as Ngay_chi_phi,
        cfaai.fb_ad_ad_id as "fact",
        case
            when cfaai.fb_account_currency = 'USD' then cfaai.spend * 23500
            else cfaai.spend
        end as "Metric",
        'ten_khach' as "ten_khach",
        cfaai.fb_ad_ad_id as ad_id,
        cfac2.name as camp_name,
        cfaa2.name as acc_name,
        split_part(cfas.name, '_', 2) as nhom_dv,
        split_part(cfas.name, '_', 1) as chi_nhanh_raw,
        cfas."name" as Ad_set
    from {{ source('paris_raw', 'core_facebook_ad_ad_insight') }} cfaai
    left join {{ source('paris_raw', 'core_facebook_ad_ad') }} cfaa on cfaa.fb_ad_ad_id = cfaai.fb_ad_ad_id
    left join {{ source('paris_raw', 'core_facebook_ad_set') }} cfas on 	cfas.fb_ad_set_id = cfaa.fb_ad_set_id
    left join {{ source('paris_raw', 'core_facebook_ad_campaign') }} cfac2 on cfac2.fb_ad_campaign_id = cfas.fb_ad_campaign_id
    left join {{ source('paris_raw', 'core_facebook_ad_account') }} cfaa2 on cfaa2.ad_account_id = cfac2.fb_ad_account_id
    where
        cfaa2.id in (7, 8, 9) and cfaai."date" > '2022-01-01'
),
b as (
    select
        a."Nguon",
        a.bang,
        a.Ngay_chi_phi,
        a."fact",
        text(a."Metric") as "Metric",
        a."ten_khach",
        a.ad_id,
        a."camp_name",
        a.acc_name,
        a.nhom_dv,
        case
            when a.chi_nhanh_raw = 'HN' then 'HÀ NỘI'
            when upper(a.chi_nhanh_raw) = 'HCM' then 'HỒ CHÍ MINH'
            when upper(a.chi_nhanh_raw) = 'VK' then 'Việt Kiều'
            when upper(a.chi_nhanh_raw) = 'VIET KIEU' then 'Việt Kiều'
            when upper(a.chi_nhanh_raw) = 'BN' then 'NHA KHOA PARIS BẮC NINH'
            when upper(a.chi_nhanh_raw) = 'HP' then 'NHA KHOA PARIS HẢI PHÒNG'
            when upper(a.chi_nhanh_raw) = 'BMT' then 'NHA KHOA PARIS BUÔN MÊ THUỘT'
            when upper(a.chi_nhanh_raw) = 'ĐN' then 'NHA KHOA PARIS ĐÀ NẴNG'
            when upper(a.chi_nhanh_raw) = 'CH' then 'HỒ CHÍ MINH'
            when upper(a.chi_nhanh_raw) = 'VINH' then 'NHA KHOA PARIS VINH'
            when upper(a.chi_nhanh_raw) = 'TN' then 'NHA KHOA PARIS THÁI NGUYÊN'
            when upper(a.chi_nhanh_raw) = 'TH' then 'NHA KHOA PARIS THANH HÓA'
            when upper(a.chi_nhanh_raw) = 'BD' then 'NHA KHOA PARIS BÌNH DƯƠNG'
            when upper(a.chi_nhanh_raw) = 'QN' then 'NHA KHOA PARIS QUẢNG NINH'
            when upper(a.chi_nhanh_raw) = 'BV' then 'HỒ CHÍ MINH'
            when upper(a.chi_nhanh_raw) = 'NTH' then 'HỒ CHÍ MINH'
            else upper(a.chi_nhanh_raw)
        end as chi_nhanh,
        a.Ad_set
    from a
)

select
    'ad' as ad_id,
    b.bang,
    'text' as ticket,
    null as requester_id, --- Added to match Union structure
    'nhanvien' as nv,
    'email' as email,
    date(b.Ngay_chi_phi) as date,
    b."Nguon",
    b.chi_nhanh,
    b.nhom_dv,
    'ten_khach' as ten_khach,
    'ma_booking' as ma_booking,
    'phong_ban'  as phong_ban,
    null as sdt,
    b."Metric" as metric
from b
