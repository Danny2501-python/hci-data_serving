{#
    Port 1:1 từ jupiter_sand_box/quentk_3_report_kpi_bonus_commission_New_sys.py,
    hàm `step_update_info()` (dòng 886-911) — cập nhật NGƯỢC 3 cột (number_used, stage_product,
    rnk_clineid_pmdate_desc) cho các dòng vừa phát sinh giao dịch tiền trong 5 ngày gần nhất
    (write_date), áp dụng cho CẢ bảng report_kpi_bonus_commission LẪN report_kpi_bonus_commission_transpose
    — bản gốc chạy 1 vòng lặp `for table in [...]` cùng 1 câu SQL, đưa vào macro dùng chung ở đây thay vì
    lặp lại code, gọi qua `post_hook` ở mỗi model mart tương ứng.

    Dùng: post_hook="{{ rkbc_update_info(this) }}"
#}
{% macro rkbc_update_info(relation) %}
with cline as (      --- Giới hạn các crm_line có cập nhật giao dịch tiền trong n ngày gần nhất
    select clineid, product_id, brand_etl, max(number_used) as number_used, min(stage_product) as stage_product
    from {{ ref('stag_payment_transfer') }} spt
    where brand_etl > 0 and write_date > (now()::date - interval '5 days')
    group by clineid, product_id, brand_etl
),
spt as (      --- Đánh thứ tự ngày thanh toán giảm dần
    select
        pm.id, pm.clineid, cline.number_used, cline.stage_product,
        dense_rank() over (partition by pm.clineid, pm.product_id, pm.brand_etl order by pm.payment_date desc) as rnk_clineid_pmdate_desc
    from {{ ref('stag_payment_transfer') }} pm
    left join cline on pm.clineid = cline.clineid and pm.product_id = cline.product_id and pm.brand_etl = cline.brand_etl
    where cline.clineid is not null
)
update {{ relation }} kpi
    set number_used = spt.number_used, stage_product = spt.stage_product,
        rnk_clineid_pmdate_desc = spt.rnk_clineid_pmdate_desc
from spt
where kpi.id = spt.id and kpi.clineid = spt.clineid
{% endmacro %}
