-- Tương đương phần 'service' của query_pm trong quentk_1_stag_crm_New_sys.py.
-- Quét cả 3 brand (kn/pr/hh) trong 1 lượt thay vì lặp query đổi brand_etl như bản Python.
-- Lọc theo int_sptr_recent_crm_scope (tương đương temp_crm_id_update) — BẮT BUỘC giữ, không phải chỉ
-- để tối ưu: nguồn crm_account_payment_detail chỉ còn ~2 tháng gần nhất, không phải kho lưu trữ đầy đủ.
select
    concat('ps-', capd.id) as id,
    'service' as product_type,
    ap.name as ma_phieu, ap.crm_id, ap.payment_date, ap.payment_method, ap.communication,
    cline.id as clineid, cline.product_id, cline.quantity, cline.uom_price, cline.number_used,
    case when cline.gia_truoc_huy > 0 then cline.gia_truoc_huy else cline.total end as total,
    capd.total_received, cline.total_received as total_received_cline,
    case when ap.payment_type = 'outbound' then -capd.prepayment_amount else capd.prepayment_amount end as payment,
    ap.payment_type,
    cline.stage as stage_product, cline.consultants_1, cline.consulting_role_1, cline.consultants_2, cline.consulting_role_2, cline.ho_tro,
    cline.price_list_id,
    ap.company_id as orgcompany_id,
    case
        when capd.company_id is not null then capd.company_id
        when ap.x_receive_company_id is null or ap.x_receive_company_id = 0 then ap.company_id
        else ap.x_receive_company_id
    end as company_id,
    ap.write_date + interval '7 hours' as write_date,
    ap.brand_id, ap.brand_etl
from {{ ref('stg_sptr_crm_account_payment_detail') }} capd
left join {{ ref('stg_sptr_account_payment') }} ap on capd.account_payment_id = ap.id and ap.brand_etl = capd.brand_etl
left join {{ ref('stg_sptr_crm_line') }} cline on capd.crm_line_id = cline.id and cline.brand_etl = capd.brand_etl
where capd.brand_etl in (1, 3, 4)
    and ap.state = 'posted' and capd.prepayment_amount <> 0
    and exists (
        select 1 from {{ ref('int_sptr_recent_crm_scope') }} s
        where s.crm_id = ap.crm_id and s.brand_etl = capd.brand_etl
    )
