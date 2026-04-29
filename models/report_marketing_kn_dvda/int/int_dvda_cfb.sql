-- CFB: Chi Phí Facebook DVDA (Intermediate)
with fb_raw as (
    select
        s.*,
        lka."chi nhánh"                                                                as chi_nhanh_lka
    from {{ ref('stg_dvda_fb_insight_v3') }} s
    left join lateral (
        select lka."chi nhánh"
        from {{ source('dvda', 'location_kangnam_adnet') }} lka
        where lka.tinh = s.vung and s.ngay_chi_phi >= lka.ngay_hh
        order by lka.ngay_hh desc limit 1
    ) lka on true
)

select
    'DV'                                                                              as ten_dv,
    'CP'                                                                              as "Nguon",
    'CP'                                                                              as "Nhom_nguon",
    'FB'                                                                              as kenh,
    m.ngay_chi_phi                                                                    as date,
    cns.nhom_dv,
    case when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) in ('HCM', 'HỒ CHÍ MINH')
              then 'BỆNH VIỆN KANGNAM SÀI GÒN'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'HÀ NỘI'
              then 'BỆNH VIỆN KANGNAM HÀ NỘI'
         when coalesce(m.chi_nhanh_lka, 'Việt Kiều') = 'Việt Kiều'
              then 'Việt Kiều'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'BẮC NINH'
              then 'VIỆN THẨM MỸ KANGNAM BẮC NINH'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'HẢI PHÒNG'
              then 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'BUÔN MÊ THUỘT'
              then 'VIỆN THẨM MỸ KANGNAM BUÔN MA THUỘT'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'ĐÀ NẴNG'
              then 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'CẦN THƠ'
              then 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'NGHỆ AN'
              then 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'THÁI NGUYÊN'
              then 'VIỆN THẨM MỸ KANGNAM THÁI NGUYÊN'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'THANH HÓA'
              then 'VIỆN THẨM MỸ KANGNAM THANH HÓA'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'BÌNH DƯƠNG'
              then 'VIỆN THẨM MỸ KANGNAM BÌNH DƯƠNG'
         when upper(coalesce(m.chi_nhanh_lka, 'Việt Kiều')) = 'VINH'
              then 'VIỆN THẨM MỸ KANGNAM VINH'
         else coalesce(m.chi_nhanh_lka, 'Việt Kiều')
    end                                                                               as chi_nhanh,
    case when m.vung = 'Ho Chi Minh City' then 'SÀI GÒN'
         when m.vung = 'Hanoi'            then 'Hà Nội'
         when coalesce(m.chi_nhanh_lka, 'Việt Kiều') = 'Việt Kiều' then 'Việt Kiều'
         when m.vung = 'Da Nang'          then 'Thành phố Đà Nẵng'
         when m.vung = 'Cần Thơ'          then 'Thành phố Cần Thơ'
         when m.vung = 'Haiphong'         then 'Thành phố Hải Phòng'
         else 'Tỉnh ' || REGEXP_REPLACE(m.vung, '\s*Province$', '')
    end                                                                               as local_k,
    m.chi_phi::text                                                                   as "Metric",
    m.type_data
from fb_raw m
left join {{ source('dvda', 'campaign_name_split') }} cns
       on upper(cns.campain_name_split) = upper(trim(split_part(m.camp_name, '_', 2)))
where trim(split_part(m.camp_name, '_', 2)) is not null
