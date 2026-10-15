{#
    (2026-10-13, user chốt) Chặn dòng chi tiết phiếu thu "ma" trong stag_payment_transfer.

    Vì sao: khi phiếu thu được PHÂN BỔ LẠI trên ERP, ERP XOÁ CỨNG các dòng chi tiết cũ
    (crm_account_payment_detail / crm_account_payment_product_detail) rồi tạo dòng mới. Job sync vào
    new_product chỉ upsert theo write_date + tombstone is_delete → không bắt được xoá cứng → dòng cũ vẫn còn,
    is_delete NULL, cộng TRÙNG với dòng mới. Ví dụ CUST.IN/2026/58667 (Kangnam Hà Nội, 10/10/2026): phiếu
    90.200.000 nhưng chi tiết 192.200.000 (dòng cũ 49 tr + 53 tr tạo 10/10, dòng mới 47,5 tr + 41,5 tr + 1,2 tr
    tạo 12/10) → doanh số Kangnam T10 dư 102.000.000 so với workbook "KANGNAM - BỘ CHỈ SỐ KINH DOANH".

    Macro trả về danh sách phiếu bị phân bổ lại (brand_etl, account_payment_id, max_create_date) khi ĐỦ cả:
      1. tổng chi tiết (2 bảng, đã bỏ is_delete) > số tiền phiếu (amount_vnd, không có thì amount) — chỉ tính phiếu
         có số tiền > 0;
      2. riêng ĐỢT tạo mới nhất (create_date trong 1 phút của max_create_date) KHÔNG vượt số tiền phiếu.
    Stg chi tiết bỏ các dòng của phiếu này tạo TRƯỚC đợt mới nhất. Phiếu chia nhiều dòng tạo cùng lúc, hoặc
    phiếu ngoại tệ (amount nhỏ, amount_vnd đúng), không bị đụng. Quét T6-T10/2026 brand 1/3: chỉ 2 phiếu thoả
    (58667 −102.000.000; CUST.IN/2026/32348 T6 −3.220.000).
    Gỡ khi team data_ops sync được xoá cứng.
#}
{% macro sptr_phieu_phan_bo_lai() %}
    (
        with ct as (
            select brand_etl, account_payment_id, prepayment_amount, create_date
            from {{ source('sptr_erp', 'crm_account_payment_detail') }}
            where coalesce(is_delete, false) = false
            union all
            select brand_etl, account_payment_id, prepayment_amount, create_date
            from {{ source('sptr_erp', 'crm_account_payment_product_detail') }}
            where coalesce(is_delete, false) = false
        ),
        ct_max as (
            select ct.*, max(create_date) over (partition by brand_etl, account_payment_id) as max_create_date
            from ct
        )
        select c.brand_etl, c.account_payment_id, c.max_create_date
        from ct_max c
        join {{ source('sptr_erp', 'account_payment') }} ap
          on ap.id = c.account_payment_id and ap.brand_etl = c.brand_etl
        where coalesce(nullif(ap.amount_vnd, 0), ap.amount) > 0
        group by c.brand_etl, c.account_payment_id, c.max_create_date, coalesce(nullif(ap.amount_vnd, 0), ap.amount)
        having sum(c.prepayment_amount) > coalesce(nullif(ap.amount_vnd, 0), ap.amount) + 1
           and coalesce(sum(c.prepayment_amount) filter (
                   where c.create_date >= c.max_create_date - interval '1 minute'), 0)
               <= coalesce(nullif(ap.amount_vnd, 0), ap.amount) + 1
    )
{% endmacro %}
