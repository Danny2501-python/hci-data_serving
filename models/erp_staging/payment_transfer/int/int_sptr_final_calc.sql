-- Tương đương đoạn cuối get_data_payment(): is_priority, sắp xếp lại, lũy kế Số tiền đã thu lần 2
-- (cộng total_received_old), đối chiếu lại tổng tiền đã thu (keep_total/keep_total_received_p),
-- total_received_recal (giá trị lũy kế cuối cùng trong ngày), và ghép id + brand_etl.
with r as (
    select
        *,
        (ma_phieu like 'PDC%' and coalesce(total_received_cline, 0) > 0) as is_priority
    from {{ ref('int_sptr_ranked') }}
),

cumsum_calc as (
    select
        r.*,
        sum(r.payment) over (
            partition by r.crm_id, r.clineid, r.product_id
            order by r.payment_date, r.is_priority desc, r.write_date
            rows between unbounded preceding and current row
        ) + coalesce(r.total_received_old, 0) as total_received_cumsum_raw
    from r
),

-- Điều kiện kiểm tra lại tổng Số tiền đã thu dựa trên Tiền đã thu hệ thống cũ hoặc Giá trị Số tiền đã
-- thu đẩy lên hệ thống mới
reconciled as (
    select
        cc.*,
        case
            when round(cc.total_received_cumsum_raw) = round(cc.total + coalesce(cc.total_received_old, 0))
                or round(cc.total) = round(cc.total_received + cc.payment)
            then cc.total
            when round(cc.payment + cc.total_received) > round(cc.total)
            then cc.payment + cc.total_received
            else cc.total_received_cumsum_raw
        end as total_received_cumsum
    from cumsum_calc cc
)

select
    concat(reconciled.id, '-', reconciled.brand_etl::text) as id,
    reconciled.product_type, reconciled.ma_phieu, reconciled.crm_id, reconciled.payment_date,
    reconciled.payment_method, reconciled.communication, reconciled.clineid, reconciled.product_id,
    reconciled.quantity, reconciled.uom_price, reconciled.number_used, reconciled.total,
    reconciled.total_received, reconciled.total_received_cumsum,
    last_value(reconciled.total_received_cumsum) over (
        partition by reconciled.brand_id, reconciled.crm_id, reconciled.clineid, reconciled.product_id, reconciled.payment_date
        order by reconciled.payment_date, reconciled.is_priority desc, reconciled.write_date
        rows between unbounded preceding and unbounded following
    ) as total_received_recal,
    reconciled.payment, reconciled.payment_type, reconciled.stage_product,
    reconciled.consultants_1, reconciled.consulting_role_1, reconciled.consultants_2, reconciled.consulting_role_2,
    reconciled.ho_tro, reconciled.price_list_id, reconciled.orgcompany_id, reconciled.company_id,
    reconciled.write_date, reconciled.brand_id, reconciled.brand_etl,
    reconciled.first_date_payment, reconciled.rnk_crm_pmdate, reconciled.rnk_clineid_pmdate, reconciled.rnk_clineid_pmdate_desc
from reconciled
