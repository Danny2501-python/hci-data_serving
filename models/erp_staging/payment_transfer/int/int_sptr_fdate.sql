-- Tương đương df_fdate: baseline "Ngày thanh toán lần đầu"/lũy kế đã thu của hệ thống cũ, lấy 1 dòng
-- mới nhất (rnk_clineid_pmdate DESC) mỗi (crm_id, clineid) từ dữ liệu brand_etl=0 đã đóng băng, giới hạn
-- các crm_id còn hoạt động gần đây (int_sptr_new_transaction). Không replicate rn_product/max_rnk_crm_date
-- của bản Python — 2 cột đó được tính nhưng không dùng ở đâu trong get_data_payment() (dead code).
with fdate_source as (
    select
        crm_id, clineid, product_id, first_date_payment, rnk_clineid_pmdate, rnk_crm_pmdate,
        total, total_received_recal as total_received_old, quantity, number_used, stage_product as stage
    from {{ ref('stg_sptr_legacy_brand0') }}
    where product_type = 'service'
        and crm_id in (select crm_id from {{ ref('int_sptr_new_transaction') }})
),
ranked as (
    select
        *,
        row_number() over (partition by crm_id, clineid order by rnk_clineid_pmdate desc) as rn
    from fdate_source
)
select
    crm_id, clineid, product_id, first_date_payment, rnk_clineid_pmdate, rnk_crm_pmdate,
    total, total_received_old, quantity, number_used, stage
from ranked
where rn = 1
