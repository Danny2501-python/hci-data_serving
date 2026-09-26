-- (2026-09-26) Nguồn "lịch sử" cho stag_payment_transfer = bảng đích hiện tại + BỒI từ bảng backup
-- đóng băng `stag_payment_transfer_backup_20260926` (copy 1 lần từ sandbox.public.stag_payment_transfer,
-- 883K dòng, dữ liệu tới 2026-09-25 — xem sources.yml).
--
-- Vì sao cần: mart stag_payment_transfer TỰ ĐỌC LẠI CHÍNH NÓ để lấy phần legacy (brand_etl=0) + cold
-- (crm_id không có giao dịch gần đây) — không có nguồn lịch sử độc lập nào khác trong new_product. Ngày
-- 2026-09-26 bảng đích bị rỗng lúc job 04:00 (data_serving_erp_staging_etl) chạy → mất VĨNH VIỄN toàn bộ
-- brand_etl=0 và lịch sử Kangnam/Paris trước ~T8/2026 (chỉ còn 32K dòng). Xem LOGIC.md mục "Sự cố mất
-- lịch sử 2026-09-26".
--
-- Quy tắc bồi (BẢNG HIỆN TẠI LUÔN ƯU TIÊN, backup chỉ lấp chỗ trống):
--   - Chỉ lấy từ backup những khách (crm_id, brand_etl) HOÀN TOÀN KHÔNG CÒN dòng nào trong bảng hiện tại.
--     Khách còn trong bảng hiện tại (kể cả đã được tính lại từ ERP, có thể khác id/số dòng so với backup)
--     → giữ nguyên bản hiện tại, KHÔNG trộn dòng backup vào (tránh đếm trùng/hồi sinh dòng đã sửa/xoá).
--   - Dòng crm_id NULL (không nhóm được theo khách) → bồi theo `id` (chỉ lấy dòng backup có id không tồn
--     tại trong bảng hiện tại).
--   - Lúc bình thường (bảng hiện tại đầy đủ) phần bồi ≈ 0 dòng; lúc bảng hiện tại rỗng/mất lịch sử →
--     backup tự làm "gốc", phần tính lại từ ERP (int_sptr_final_calc) bồi thêm các khách gần đây.
-- Hạn chế đã biết: khách thật sự bị xoá HẾT mọi dòng khỏi bảng đích sau 2026-09-26 sẽ bị backup "hồi
-- sinh" (hiếm, chấp nhận). Backup là bản ĐÓNG BĂNG — KHÔNG job nào được ghi đè/đồng bộ lại bảng này.
--
-- Ép kiểu tường minh về đúng kiểu cột của bảng đích dbt (backup copy từ sandbox có vài cột khác kiểu:
-- integer/numeric thay vì double precision/bigint).

-- Materialized TABLE (không phải view như các stg khác): tính 1 lần/lần chạy thay vì mỗi model int
-- đọc lại view (NOT EXISTS trên ~900K dòng), và bảng không bị Postgres DROP ... CASCADE kéo theo khi mart
-- stag_payment_transfer được build lại (view đọc source() thì bị — xem Lỗi 3 trong LOGIC.md).
{{ config(materialized='table', indexes=[{'columns': ['crm_id', 'brand_etl']}]) }}

{% set cols = [
    ('id', 'varchar'), ('ma_phieu', 'varchar'), ('crm_id', 'integer'), ('payment_date', 'date'),
    ('payment_method', 'varchar'), ('clineid', 'integer'), ('product_id', 'integer'),
    ('quantity', 'double precision'), ('uom_price', 'double precision'), ('number_used', 'double precision'),
    ('total', 'double precision'), ('total_received', 'numeric'), ('total_received_cumsum', 'double precision'),
    ('total_received_recal', 'double precision'), ('payment', 'numeric'), ('payment_type', 'varchar'),
    ('stage_product', 'varchar'), ('consultants_1', 'integer'), ('consulting_role_1', 'varchar'),
    ('consultants_2', 'integer'), ('consulting_role_2', 'varchar'), ('ho_tro', 'integer'),
    ('price_list_id', 'integer'), ('orgcompany_id', 'integer'), ('company_id', 'integer'),
    ('communication', 'text'), ('product_type', 'varchar'), ('write_date', 'timestamp'),
    ('brand_id', 'integer'), ('brand_etl', 'integer'), ('first_date_payment', 'date'),
    ('rnk_crm_pmdate', 'bigint'), ('rnk_clineid_pmdate', 'bigint'), ('rnk_clineid_pmdate_desc', 'bigint')
] %}

with hien_tai as (
    select
        {%- for c, t in cols %}
        {{ c }}::{{ t }} as {{ c }}{{ "," if not loop.last }}
        {%- endfor %}
    from {{ source('sptr_legacy', 'stag_payment_transfer') }}
),

backup as (
    select
        {%- for c, t in cols %}
        {{ c }}::{{ t }} as {{ c }}{{ "," if not loop.last }}
        {%- endfor %}
    from {{ source('sptr_legacy', 'stag_payment_transfer_backup_20260926') }}
),

backup_boi as (
    select b.*
    from backup b
    where (
            b.crm_id is not null
        and not exists (
            select 1 from hien_tai h
            where h.crm_id = b.crm_id and h.brand_etl = b.brand_etl
        )
    )
    or (
            b.crm_id is null
        and not exists (select 1 from hien_tai h where h.id = b.id)
    )
)

select *, false as tu_backup from hien_tai
union all
select *, true as tu_backup from backup_boi
