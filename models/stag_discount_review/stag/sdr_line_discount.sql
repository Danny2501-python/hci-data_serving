-- Pass 5 -> 8 của function gốc, giữ nguyên thứ tự cột:
--   promo_discount   : tách KM marketing (MD, trừ MD - Cơ sở) / KM cơ sở (CS), gắn booking
--   over_discount    : tiền KM vượt trần giá sàn (price_min_new), chỉ dòng dịch vụ
--   permission_table : chi nhánh / thương hiệu phân quyền
--   data_other       : no_tt (thứ tự phiếu theo line), cummulative_line (tổng thanh toán của line)
--
-- Khác function gốc:
--   - Chi nhánh / thương hiệu phân quyền lấy từ m_res_company (+ res_brand) join
--     id + brand_etl, thay cho res_company_trans_field (lateral theo expiration_date).
--   - Join / partition thêm brand_etl (id chỉ duy nhất trong 1 brand_etl).
--   - brand_etl (cột cuối, đi kèm từ sdr_line_union qua c.* / d.*) không có trong output.

with promo_discount as (
    select
        c.*,
        coalesce(case
            when c.category_source_code = 'MD' and c."source" not in ('MD - Cơ sở', 'MD - Cơ sở thuê ngoài') then c.amout_test_discount
        end, 0) as discount_mkt,
        amout_test_discount_cs + coalesce(case
            when c.category_source_code <> 'MD' or c."source" in ('MD - Cơ sở', 'MD - Cơ sở thuê ngoài') then c.amout_test_discount
        end, 0) as discount_cs,
        cl.create_date,
        cl.arrival_date,
        cl.booking,
        cl.contact_name,
        cl.code_customer,
        cl.stage_bk,
        cl.type_crm_id,
        cl.brand_id_bk,
        cl.company_id_bk,
        case
            when c.company_id = cl.company_id_bk then c.company_id
            when c.company_id <> cl.company_id_bk then c.company_id
            else cl.company_id_bk
        end cnpq,
        cl.campaign
    from {{ ref('sdr_line_union') }} c
    join {{ ref('sdr_lead') }} cl on cl.id = c.crm_id and cl.brand_etl = c.brand_etl
),
over_discount as (
    select
        d.*,
        round(price_min_new::numeric, 0) as amount_price_min,
        case
            when type_data = 'service_data' and d.discount_mkt <> 0 and d.discount_mkt - (abs(d.total_before_discount) - round(price_min_new::numeric, 0)) > 0 then d.discount_mkt - (abs(d.total_before_discount) - round(price_min_new::numeric, 0))
            else 0
        end as over_discount_mkt,
        case
            when d."source" <> 'K - CBNV' and type_data = 'service_data' and d.discount_mkt = 0 and d.discount_cs <> 0 and d.discount_cs - (abs(d.total_before_discount) - round(price_min_new::numeric, 0)) > 0 then d.discount_cs - (abs(d.total_before_discount) - round(price_min_new::numeric, 0))
            when d."source" <> 'K - CBNV' and type_data = 'service_data' and d.discount_cs <> 0 and d.discount_mkt <> 0 and d.discount_mkt - (abs(d.total_before_discount) - round(price_min_new::numeric, 0)) < 0 and d.discount_mkt + d.discount_cs - (abs(d.total_before_discount) - round(price_min_new::numeric, 0)) > 0
                then d.discount_mkt + d.discount_cs - (abs(d.total_before_discount) - round(price_min_new::numeric, 0))
            when d."source" <> 'K - CBNV' and type_data = 'service_data' and d.discount_cs <> 0 and d.discount_mkt <> 0 and d.discount_mkt - (abs(d.total_before_discount) - round(price_min_new::numeric, 0)) > 0 then d.discount_cs
            else 0
        end as over_discount_cs
    from promo_discount d
),
permission_table as (
    select
        d.*,
        case
            when total = payment and ma_phieu is not null then 'done'
            when total > payment and ma_phieu is not null then 'tt_lan'
            when ma_phieu is null and d.stage = 'cancel' then 'dv_cancel'
        end as "trang_thai",
        row_number() over (partition by d.brand_etl, clineid, crm_id order by dim_date asc) "no_payment_by_line",
        row_number() over (partition by d.brand_etl, d.id, crm_id) no_id,
        mrc.id company_id_pq,
        mrc.brand_id as brand_id_pq,
        mrc."name" "chinhanh",
        rb."name" "thuonghieu"
    from (select * from over_discount where dim_date is not null) d
    left join {{ source('sdr_base', 'm_res_company') }} mrc
        on mrc.id = d.cnpq and mrc.brand_etl = d.brand_etl
    left join {{ source('sdr_base', 'res_brand') }} rb
        on rb.id = mrc.brand_id and rb.brand_etl = mrc.brand_etl
)
select
    sdr.*,
    row_number() over (partition by sdr.brand_etl, sdr.crm_id, sdr.clineid order by dim_date, id) no_tt,
    sum(payment) over (partition by sdr.brand_etl, sdr.crm_id, sdr.clineid) cummulative_line
from permission_table sdr
