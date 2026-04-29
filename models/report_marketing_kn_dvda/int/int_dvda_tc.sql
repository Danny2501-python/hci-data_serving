-- TC: Thành Công — khách đến cửa có tong_tien > 0 và vao_so = posted

select
    stks.ten_dv,
    stks.nguon_moi                                                                    as "Nguon",
    stks.nhom_nguon_moi                                                               as "Nhom_nguon",
    case when stks.nguon_moi like '%Facebook%' then 'FB'
         when stks.nguon_moi like '%Seo%'
           or stks.nguon_moi like '%Google%'
           or stks.nguon_moi like '%Hotline%' then 'Web'
         else 'Khác' end                                                              as kenh,
    stks.ngay_den_cua                                                                 as date,
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
    'TC'                                                                              as type_data
from {{ ref('stg_common_tongquan_khachhang') }} stks
left join {{ ref('stg_dvda_ecl') }} cl on cl.id = stks.id
left join {{ source('dvda', 'res_country_state') }} rcs on rcs.id = cl.state_id and rcs.brand_etl = 1
where stks.thuong_hieu = 'Kangnam'
  and stks.ngay_den_cua >= '20230601'
  and stks.nhom_dv <> 'Sản Phẩm'
  and stks.nhom_dv is not null
  and stks.ngay_den_cua is not null
  and stks.tong_tien > 0
  and stks.vao_so = 'posted'
  and stks.date_time between '2022-01-01' and current_date
