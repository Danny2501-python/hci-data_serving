-- Tương đương đoạn tính rank/lũy kế lần 1 + gộp cline_info/crm_info (từ df_fdate) trong get_data_payment().
-- Bỏ qua total_received_cumsum lần 1 (df_spt.groupby(...).cumsum() ở dòng 990 bản gốc): bị ghi đè hoàn
-- toàn bởi lần tính thứ 2 (sau khi sort lại ở int_sptr_final_calc) trước khi được đọc ở bất kỳ đâu --
-- code chết, không cần dịch.
with base as (
    select * from {{ ref('int_sptr_union') }}
),

fdate as (
    select * from {{ ref('int_sptr_fdate') }}
),

crm_info as (
    select crm_id, min(first_date_payment) as first_date_payment, max(rnk_crm_pmdate) as rnk_crm_pmdate
    from fdate
    group by crm_id
),

windowed as (
    select
        b.*,
        min(b.payment_date) over (partition by b.brand_etl, b.clineid, b.product_type) as first_date_payment_calc,
        dense_rank() over (partition by b.brand_etl, b.crm_id order by b.payment_date) as rnk_crm_pmdate_calc,
        dense_rank() over (partition by b.brand_etl, b.clineid, b.product_type order by b.payment_date) as rnk_clineid_pmdate_calc,
        dense_rank() over (partition by b.brand_etl, b.clineid, b.product_type order by b.payment_date desc) as rnk_clineid_pmdate_desc
    from base b
)

select
    w.id, w.product_type, w.ma_phieu, w.crm_id, w.payment_date, w.payment_method, w.communication,
    w.clineid, w.product_id, w.uom_price,
    w.total_received, w.total_received_cline, w.payment, w.payment_type, w.stage_product,
    w.consultants_1, w.consulting_role_1, w.consultants_2, w.consulting_role_2, w.ho_tro, w.price_list_id,
    w.orgcompany_id, w.company_id, w.write_date, w.brand_id, w.brand_etl,
    coalesce(ci.first_date_payment, w.first_date_payment_calc) as first_date_payment,
    w.rnk_crm_pmdate_calc + coalesce(ci.rnk_crm_pmdate, 0) as rnk_crm_pmdate,
    w.rnk_clineid_pmdate_desc,
    w.rnk_clineid_pmdate_calc + coalesce(fd.rnk_clineid_pmdate, 0) as rnk_clineid_pmdate,
    case when coalesce(fd.total, 0) > w.total then fd.total else w.total end as total,
    case when coalesce(fd.quantity, 0) > w.quantity then fd.quantity else w.quantity end as quantity,
    w.number_used + coalesce(fd.number_used, 0) as number_used,
    fd.total_received_old
from windowed w
left join fdate fd on fd.crm_id = w.crm_id and fd.clineid = w.clineid
left join crm_info ci on ci.crm_id = w.crm_id
