{{ config(materialized='table') }}

-- Mapping "nguồn cũ" -> "nguồn mới" theo từng brand_etl, dựa trên bảng cầu
-- utm_source_old_source_rel (source_id = nguồn mới, old_source_id = nguồn cũ).
-- 1 nguồn mới có thể gộp nhiều nguồn cũ (không phải 1-1).
--
-- Gotcha (xem models/common/knowledge.md mục 1): id của utm_source KHÔNG unique
-- toàn cục giữa các brand_etl -> mọi join phải kèm brand_etl của chính bảng rel
-- (nguồn đáng tin nhất), không dựa vào cờ is_new_source/is_old_source trên
-- utm_source vì cờ này bị NULL toàn bộ ở brand_etl = 4 và 7.
--
-- Coverage: có dữ liệu mapping cho brand_etl 1, 3, 4, 8. brand_etl = 7 hiện
-- chưa có dòng nào trong utm_source_old_source_rel.
--
-- Gap đã xác nhận (2026-08-09): brand_etl = 4 (bệnh viện Hồng Hà, xác nhận
-- với người dùng) có old_source_name khớp đủ 38/38, nhưng new_source_name ra
-- NULL 100% (0/38) — source_id phía "nguồn mới" của các dòng rel.brand_etl=4
-- không tồn tại trong utm_source ở brand_etl=4 (utm_source brand_etl=4 có
-- is_new_source/is_old_source NULL toàn bộ, có thể chưa từng được migrate
-- sang hệ "nguồn mới" riêng).
--
-- Đã thử nghiệm join utm_source.brand_etl=8 thay vì =4 cho phía source_id:
-- khớp 100% (38/38), tên hợp lý — NHƯNG đã hỏi lại người dùng và xác nhận
-- brand_etl=8 (THV, xem report_thv_sale_online) là 1 thương hiệu KHÁC,
-- không phải Hồng Hà. Match 100% đó là TRÙNG HỢP NGẪU NHIÊN do id trùng chéo
-- giữa brand_etl (gotcha mục 1, common/knowledge.md) — KHÔNG được áp dụng
-- fix này. Giữ NULL cho new_source_name của brand_etl=4 (an toàn hơn join
-- sai chéo brand) cho tới khi có nguồn dữ liệu "nguồn mới" thật sự của Hồng
-- Hà (có thể ERP Hồng Hà chưa có hệ nguồn mới, hoặc chưa đồng bộ).

with rel as (
    select *
    from {{ source('public', 'utm_source_old_source_rel') }}
),

utm_source as (
    select *
    from {{ source('public', 'utm_source') }}
)

select
    rel.brand_etl,
    rel.old_source_id,
    old_src.name as old_source_name,
    rel.source_id as new_source_id,
    new_src.name as new_source_name,
    new_src.category_id as new_source_category_id
from rel
left join utm_source old_src
    on old_src.id = rel.old_source_id
    and old_src.brand_etl = rel.brand_etl
left join utm_source new_src
    on new_src.id = rel.source_id
    and new_src.brand_etl = rel.brand_etl
