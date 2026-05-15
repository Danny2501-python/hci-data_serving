WITH b as (
    SELECT 
        'Chi tiết đơn hàng'::text AS "table",
        'Thành tiền'::text AS type_data,
        a.id,
        a.code,
        a.product,
        a.booking_id,
        a.price_subtotal AS old_data,
        lag(a.price_subtotal, '-1'::integer) OVER (PARTITION BY a.id ORDER BY a.start_date) AS new_data,
        lag(a.start_date, '-1'::integer) OVER (PARTITION BY a.id ORDER BY a.start_date) AS date_changed,
        lag(a.write_uid, '-1'::integer) OVER (PARTITION BY a.id ORDER BY a.start_date) AS write_uid,
        a.status,
        a.so_id,
        a.invoice_date,
        a.brand_etl
    FROM {{ ref('stg_bcsxdl_ks_sale_order_line_trans_field') }} a 
)
SELECT 
    b."table",
    b.type_data,
    b.id,
    b.code,
    b.product,
    b.booking_id,
    b.old_data,
    b.new_data,
    b.date_changed + '07:00:00'::interval AS date_changed,
    b.write_uid,
    rp.name AS user_changed,
    rp.code_customer,
    b.so_id,
    b.invoice_date + '07:00:00'::interval AS invoice_date,
    b.brand_etl
FROM b
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru 
        ON ru.id = b.write_uid 
        AND ru.brand_etl = b.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp 
        ON rp.id = ru.partner_id 
        AND ru.brand_etl = rp.brand_etl
WHERE b.status <> 'Y'::text