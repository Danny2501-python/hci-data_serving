-- DS: Doanh Số — doanh thu từ stag_payment_transfer (Laser/Spa/Card)

select
    sp.product                                                                        as ten_dv,
    ss.source                                                                         as "Nguon",
    ss.category_source                                                                as "Nhom_nguon",
    case when ss.source like '%Facebook%' then 'FB'
         when ss.source like '%Seo%'
           or ss.source like '%Google%'
           or ss.source like '%Hotline%' then 'Web'
         else 'Khác' end                                                              as kenh,
    date(std.payment_date)                                                            as date,
    sp.product_category                                                               as nhom_dv,
    case when (case when cl3.vk = 'marketing' then 'Việt Kiều' else mrc.name end) = 'VIỆN THẨM MỸ KANGNAM BẠCH MAI'
              then 'BỆNH VIỆN KANGNAM HÀ NỘI'
         when (case when cl3.vk = 'marketing' then 'Việt Kiều' else mrc.name end)
              in ('BỆNH VIỆN KANGNAM NGUYỄN TRÃI', 'BỆNH VIỆN KANGNAM SÀI GÒN')
              then 'BỆNH VIỆN KANGNAM SÀI GÒN'
         else  (case when cl3.vk = 'marketing' then 'Việt Kiều' else mrc.name end)
    end                                                                               as chi_nhanh,
    case when rcs.name = 'Thành phố Hồ Chí Minh' then 'SÀI GÒN'
         when rcs.name = 'Thành phố Hà Nội'       then 'Hà Nội'
         when rcs.name is null                     then 'KXĐ'
         when rcs.code not like '%VN-%'            then 'Việt Kiều'
         else rcs.name end                                                            as local_k,
    std.payment::text                                                                 as "Metric",
    'DS'                                                                              as type_data
from {{ source('rmkd', 'stag_payment_transfer') }} std
left join {{ ref('stg_rmkd_cline') }} cl2 on cl2.id = std.clineid and cl2.crm_id = std.crm_id
left join {{ ref('stg_rmkd_ecl') }}   cl3 on cl2.crm_id = cl3.id
left join {{ source('rmkd', 'res_country_state') }}  rcs on rcs.id = cl3.state_id and rcs.brand_etl = 1
left join {{ source('rmkd', 'view_stag_products') }}  sp  on sp.product_id = cl2.product_id and sp.brand_etl = 1
left join {{ source('rmkd', 'stag_sources') }}        ss  on ss.old_id = cl3.source_id and ss.brand_id = 1
left join {{ source('rmkd', 'm_res_company') }}       mrc on mrc.id = std.company_id and mrc.brand_etl = 1
left join lateral (
    select b.brand_id
    from {{ source('rmkd', 'res_company_trans_field') }} b
    where b.id = std.company_id
      and date(b.expiration_date) >= date(std.payment_date)
    limit 1
) cn on true
where std.brand_id = 1
  and std.brand_etl in (0, 1)
  and cn.brand_id = 1
  and sp.his_service_type in ('Laser', 'Spa', 'Card')

