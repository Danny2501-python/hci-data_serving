SELECT 
    ksoltf.id,
    ksoltf.order_id,
    ksoltf.product_uom_qty,
    ksoltf.price_subtotal,
    ksoltf.state,
    ksoltf.start_date,
    ksoltf.expiration_date,
    ksoltf.status,
    ksoltf.write_uid,
    ksoltf.brand_etl,
    so.name AS code,
    sol.name AS product,
    so.booking_id,
    so.id AS so_id,
    so.invoice_date
FROM {{ source  ('bao_cao_sua_xoa_du_lieu', 'ks_sale_order_line_trans_field') }} ksoltf
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'sale_order_line') }} sol ON ksoltf.id = sol.id AND ksoltf.brand_etl = sol.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'sale_order') }} so ON so.id = ksoltf.order_id AND ksoltf.brand_etl = so.brand_etl