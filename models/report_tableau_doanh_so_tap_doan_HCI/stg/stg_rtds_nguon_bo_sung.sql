-- (2026-10-13, user chốt) Nguồn CRM Hồng Hà/THV (brand_etl 4/8) KHÔNG có trong stag_sources — chủ yếu nhóm
-- "DG - …" (id 593–611, tạo 2025-06-11, dòng Dr Giang/THV). stag_sources chỉ có 214 nguồn (brand_id 0/1/3/4) nên
-- khách THV đến cửa 2026 bị NULL nguồn ~37% (2.411/6.570 dòng), Hồng Hà ~1.170 dòng từ 2025.
-- Bảng này trả cùng tên cột với stag_sources (old_id, source, newcat_source, category_id) để coalesce sau
-- stag_sources: tên nguồn = utm_source.name (khoá id + brand_etl, không trùng), nhóm = crm_category_source.name.
-- crm_category_source KHÔNG có brand_etl 4 → Hồng Hà lấy nhóm cùng id ở brand khác (tên giống nhau: 113 DG - Nguồn
-- Marketing, 114 Đối tác KD, 115 Loyalty-WOM-MGM, 116 Nguồn khác), ưu tiên cùng brand_etl rồi brand_etl 8.
-- Giữ TÊN GỐC (user chốt không ánh xạ sang nhóm Kangnam).
with cat as (
    select distinct on (id, brand_etl_dich)
        id, brand_etl_dich, name
    from (
        select c.*, b.brand_etl_dich
        from {{ source('rtds_source', 'crm_category_source') }} c
        cross join (values (4), (8)) b(brand_etl_dich)
    ) x
    order by id, brand_etl_dich, (brand_etl = brand_etl_dich) desc, (brand_etl = 8) desc, brand_etl
)

select
    u.brand_etl,
    u.id as old_id,
    u.name as source,
    cat.name as newcat_source,
    u.category_id
from {{ source('rtds_source', 'utm_source') }} u
left join cat on cat.id = u.category_id and cat.brand_etl_dich = u.brand_etl
where u.brand_etl in (4, 8)
  and not exists (
      select 1 from {{ source('rtds_source', 'stag_sources') }} s where s.old_id = u.id
  )
