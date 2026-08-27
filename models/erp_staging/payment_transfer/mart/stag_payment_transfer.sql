{{ config(alias='stag_payment_transfer') }}

-- Tương đương write_stag_payment_transfer() trong quentk_1_stag_crm_New_sys.py.
-- (2026-08-27) ĐÃ CUTOVER — alias ghi thẳng bảng thật 'stag_payment_transfer', task Airflow cũ
-- (write_stag_payment_transfer trong quentk_1_stag_crm_New_sys.py) đã tắt/xoá (user xác nhận). Các
-- model/report khác trong repo giờ nên dùng ref('stag_payment_transfer') thay vì
-- source(..., 'stag_payment_transfer') khi có thể — xem mục "Cutover" trong LOGIC.md để biết các
-- bước còn lại CHƯA xác nhận xong (đặc biệt bảng đi kèm stag_payment_transfer_grby_date).
--
-- 3 phần, UNION ALL:
--   1. legacy (brand_etl=0)      -- đóng băng, không ETL nào tái tạo được
--   2. cold   (brand 1/3/4)      -- crm_id KHÔNG có giao dịch gần đây, lấy nguyên từ bảng thật vì
--                                    nguồn ERP chi tiết không còn đủ lịch sử để tính lại (xem knowledge.md)
--   3. computed (brand 1/3/4)    -- crm_id CÓ giao dịch gần đây, tính lại từ ERP nguồn (tương đương
--                                    get_data_payment() đúng phạm vi temp_crm_id_update gốc)
-- Phần 1, 2 lấy nguyên từ bảng thật (không cần NULLIF('')) — chỉ phần 3 (mới build từ SQL trực tiếp,
-- không qua CSV/COPY như bản Python) mới cần NULLIF('') để khớp hành vi COPY CSV cũ — xem
-- erp_staging/products/knowledge.md mục 7.
with legacy as (
    select * from {{ ref('stg_sptr_legacy_brand0') }}
),

cold as (
    select * from {{ ref('int_sptr_cold_brand134') }}
),

computed as (
    select * from {{ ref('int_sptr_final_calc') }}
)

select
    id, ma_phieu, crm_id, payment_date, payment_method, clineid, product_id, quantity, uom_price,
    number_used, total, total_received, total_received_cumsum, total_received_recal, payment,
    payment_type, stage_product, consultants_1, consulting_role_1, consultants_2, consulting_role_2,
    ho_tro, price_list_id, orgcompany_id, company_id, communication, product_type, write_date,
    brand_id, brand_etl, first_date_payment, rnk_crm_pmdate, rnk_clineid_pmdate, rnk_clineid_pmdate_desc
from legacy

union all

select
    id, ma_phieu, crm_id, payment_date, payment_method, clineid, product_id, quantity, uom_price,
    number_used, total, total_received, total_received_cumsum, total_received_recal, payment,
    payment_type, stage_product, consultants_1, consulting_role_1, consultants_2, consulting_role_2,
    ho_tro, price_list_id, orgcompany_id, company_id, communication, product_type, write_date,
    brand_id, brand_etl, first_date_payment, rnk_crm_pmdate, rnk_clineid_pmdate, rnk_clineid_pmdate_desc
from cold

union all

select
    id,
    nullif(ma_phieu, '') as ma_phieu,
    crm_id, payment_date,
    nullif(payment_method, '') as payment_method,
    clineid, product_id, quantity, uom_price, number_used, total, total_received,
    total_received_cumsum, total_received_recal, payment,
    nullif(payment_type, '') as payment_type,
    nullif(stage_product, '') as stage_product,
    consultants_1,
    nullif(consulting_role_1, '') as consulting_role_1,
    consultants_2,
    nullif(consulting_role_2, '') as consulting_role_2,
    ho_tro, price_list_id, orgcompany_id, company_id,
    nullif(communication, '') as communication,
    nullif(product_type, '') as product_type,
    write_date, brand_id, brand_etl,
    first_date_payment, rnk_crm_pmdate, rnk_clineid_pmdate, rnk_clineid_pmdate_desc
from computed
