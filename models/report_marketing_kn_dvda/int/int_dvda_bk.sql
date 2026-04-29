-- BK: Booking HL — loai_ban_ghi=2, date dùng ngay_hl

select
    stks.ten_dv,
    stks.nguon_moi                                                                    as "Nguon",
    stks.nhom_nguon_moi                                                               as "Nhom_nguon",
    case when stks.nguon_moi like '%Facebook%' then 'FB'
         when stks.nguon_moi like '%Seo%'
           or stks.nguon_moi like '%Google%'
           or stks.nguon_moi like '%Hotline%' then 'Web'
         else 'Khác' end                                                              as kenh,
    stks.ngay_hl                                                                      as date,
    stks.nhom_dv,
    case when (case when stks.vk = 'marketing' then 'Việt Kiều' else stks.chi_nhanh end) = 'VIỆN THẨM MỸ KANGNAM BẠCH MAI'
              then 'BỆNH VIỆN KANGNAM HÀ NỘI'
         when (case when stks.vk = 'marketing' then 'Việt Kiều' else stks.chi_nhanh end)
              in ('BỆNH VIỆN KANGNAM NGUYỄN TRÃI', 'BỆNH VIỆN KANGNAM SÀI GÒN')
              then 'BỆNH VIỆN KANGNAM SÀI GÒN'
         else  (case when stks.vk = 'marketing' then 'Việt Kiều' else stks.chi_nhanh end)
    end                                                                               as chi_nhanh,
    case when rcs.name = 'Thành phố Hồ Chí Minh' then 'SÀI GÒN'
         when rcs.name = 'Thành phố Hà Nội'       then 'Hà Nội'
         when rcs.name is null                     then 'KXĐ'
         when rcs.code not like '%VN-%'            then 'Việt Kiều'
         else rcs.name end                                                            as local_k,
    stks.sdt                                                                          as "Metric",
    'BKHL'                                                                            as type_data
from {{ ref('stg_common_tongquan_khachhang') }} stks
left join lateral (
    select b.brand_id
    from {{ source('dvda', 'res_company_trans_field') }} b
    where b.id = stks.chinhanhphanquyen
      and date(b.expiration_date) >= date(stks.ngay_hl)
    limit 1
) cn on true
left join {{ ref('stg_dvda_ecl') }} cl on cl.id = stks.id
left join {{ source('dvda', 'res_country_state') }} rcs on rcs.id = cl.state_id and rcs.brand_etl = 1
where cn.brand_id = 1
  and stks.loai_ban_ghi = 2
  and stks.nhom_dv <> 'Sản Phẩm'
  and stks.nhom_dv is not null
  and stks.ngay_tao is not null
  and stks.date_time between '2022-01-01' and current_date
