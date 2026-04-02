with a as (
    select
        distinct mik."tên chiến dịch",
        mik."vùng",
        mik."id chiến dịch"::text as "id chiến dịch" ,
        nullif(mik."ngày"::text, '')::date as "ngày",
        mik."người liên hệ qua nhắn tin mới",
        lka.tinh,
        lka."chi nhánh",
        lka.ngay_hh,
        trim(both from split_part(mik."tên chiến dịch", '_'::text, 1)) as cn,
        lka."chi nhánh" as chi_nhanh_qc,
        trim(both from split_part(mik."tên chiến dịch", '_'::text, 2)) as nhom_dv_qc,
        mik."tên chiến dịch" as ten_ad,
        mik."vùng" as local
    from {{ source('ads_raw_data', 'm_inbox_kangnam') }} mik
    left join lateral (
        select
            lka_1.tinh,
            lka_1."chi nhánh",
            lka_1.ngay_hh
        from {{ source('master_data', 'location_kangnam_adnet') }} lka_1
        where lka_1.tinh = mik."vùng" and nullif(mik."ngày"::text, '')::date >= lka_1.ngay_hh
        order by lka_1.ngay_hh desc
        limit 1
    ) lka on true
    where nullif(mik."ngày"::text, '')::date >= '20250801'
),

i as (
    select
        case
            when a.cn ilike '%Hai Ngoai%'::text then 'VIỆT KIỀU'::text
            when a.cn ilike '%QUOC TE%'::text then 'QUỐC TẾ'::text
            else 'no'::text
        end as vk,
        a.local,
        a.ten_ad,
        'FB'::text as channel,
        a."ngày" as ngay,
        a.nhom_dv_qc as nhom_dv_cam,
        cns.nhom_dv as nhom_dv_sys_chuan,
        case
            when a."chi nhánh" is null
            and a.cn not ilike '%QUOC TE%' then 'VIỆT KIỀU'::text
            when a."chi nhánh" is null
            and a.cn ilike '%QUOC TE%' then 'QUỐC TẾ'::text
            else a."chi nhánh"
        end as chi_nhanh,
        a."người liên hệ qua nhắn tin mới"::text as "Metric",
        'inbox'::text as type_data
    from a
    left join {{ source('master_data', 'campaign_name_split') }} cns on upper(cns.campain_name_split) = upper(a.nhom_dv_qc)
    where a."người liên hệ qua nhắn tin mới" is not null
)

select
    i.vk,
    'DV'::text as dv,
    'IB'::text as "Nguon",
    'IB'::text as "Nhom_nguon",
    i.channel as kenh,
    i.ngay as date,
    i.nhom_dv_sys_chuan as nhom_dv,
    case
        when i.chi_nhanh = 'HÀ NỘI'::text then 'BỆNH VIỆN KANGNAM HÀ NỘI'::text
        when upper(i.chi_nhanh) = 'HCM'::text then 'BỆNH VIỆN KANGNAM SÀI GÒN'::text
        when upper(i.chi_nhanh) = 'VK'::text then 'VIỆT KIỀU'::text
        when upper(i.chi_nhanh) = 'BẮC NINH'::text then 'VIỆN THẨM MỸ KANGNAM BẮC NINH'::text
        when upper(i.chi_nhanh) = 'HẢI PHÒNG'::text then 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'::text
        when upper(i.chi_nhanh) = 'BUÔN MÊ THUỘT'::text then 'VIỆN THẨM MỸ KANGNAM BUÔN MA THUỘT'::text
        when upper(i.chi_nhanh) = 'ĐÀ NẴNG'::text then 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'::text
        when upper(i.chi_nhanh) = 'CẦN THƠ'::text then 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'::text
        when upper(i.chi_nhanh) = 'NGHỆ AN'::text then 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'::text
        when upper(i.chi_nhanh) = 'THÁI NGUYÊN'::text then 'VIỆN THẨM MỸ KANGNAM THÁI NGUYÊN'::text
        when upper(i.chi_nhanh) = 'THANH HÓA'::text then 'VIỆN THẨM MỸ KANGNAM THANH HÓA'::text
        when upper(i.chi_nhanh) = 'BÌNH DƯƠNG'::text then 'VIỆN THẨM MỸ KANGNAM BÌNH DƯƠNG'::text
        else upper(i.chi_nhanh)
    end as chi_nhanh,
    case
        when i.local = 'Ho Chi Minh City'::text then 'SÀI GÒN'::text
        when i.local = 'Hanoi'::text then 'Hà Nội'::text
        when i.chi_nhanh = 'VIỆT KIỀU'::text then 'VIỆT KIỀU'::text
        when i.chi_nhanh = 'QUỐC TẾ'::text then 'QUỐC TẾ'::text
        when i.local = 'Da Nang'::text then 'Thành phố Đà Nẵng'::text
        when i.local = 'Cần Thơ'::text then 'Thành phố Cần Thơ'::text
        when i.local = 'Haiphong'::text then 'Thành phố Hải Phòng'::text
        else ('Tỉnh'::text || ' '::text) || regexp_replace(i.local, '\s*Province$'::text, ''::text)
    end as local_k,
    case
        when i.chi_nhanh = 'VIỆT KIỀU'::text then 'VIỆT KIỀU'::text
        when i.chi_nhanh = 'QUỐC TẾ'::text then 'QUỐC TẾ'::text
        else 'Việt Nam'::text
    end as quoc_gia,
    i."Metric",
    i.type_data,
    0 as ticket_id
from i


