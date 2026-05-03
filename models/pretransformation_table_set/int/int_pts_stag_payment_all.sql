--Bang int_pts_stag_payment_all: gom cac bang sau:
  --stg_pts_stag_payment_all_payment_transfer
  --stg_pts_stag_payment_all_payment

WITH all_payment_and_transfer AS (
  -- Bảng outbound
SELECT 
    CONCAT('to-',ptf.id) AS id, 
    ptf.product_typef AS product_type,
    ptf.ma_phieu AS ma_phieu,
    ptf.crm_id AS crm_id,
    ptf.payment_date AS payment_date,
    ptf.payment_method AS payment_method,
    ptf.communication AS communication,
    ptf.clineidf AS clineid,
    ptf.product_idf AS product_id,
    ptf.quantityf AS quantity,
    ptf.uom_pricef AS uom_price,
    ptf.number_usedf AS number_used,
    ptf.totalf AS total,
    ptf.total_receivedf AS total_received,
    ptf.total_received_clinef AS total_received_cline,
    -1 * ptf.transfer_amount AS payment,
    'outbound' AS payment_type,
    ptf.stage_productf AS stage_product,
    ptf.consultants_1f AS consultants_1,
    ptf.consulting_role_1f AS consulting_role_1,
    ptf.consultants_2f AS consultants_2,
    ptf.consulting_role_2f AS consulting_role_2,
    ptf.ho_trof AS ho_tro,
    ptf.price_list_idf AS price_list_id,
    ptf.orgcompany_id AS orgcompany_id,
    ptf.company_idf AS company_id,
    ptf.write_date AS write_date,
    ptf.brand_id AS brand_id,
    ptf.brand_etl AS brand_etl
FROM {{ref('stg_pts_stag_payment_all_payment_transfer')}} ptf
UNION ALL
-- Bảng inbound
SELECT 
    CONCAT('ti-',ptt.id) AS id, 
    ptt.product_typet AS product_type,
    ptt.ma_phieu AS ma_phieu,
    ptt.crm_id AS crm_id,
    ptt.payment_date AS payment_date,
    ptt.payment_method AS payment_method,
    ptt.communication AS communication,
    ptt.clineidt AS clineid,
    ptt.product_idt AS product_id,
    ptt.quantityt AS quantity,
    ptt.uom_pricet AS uom_price,
    ptt.number_usedt AS number_used,
    ptt.totalt AS total,
    ptt.total_receivedt AS total_received,
    ptt.total_received_clinet AS total_received_cline,
    ptt.transfer_amount AS payment,
    'inbound' AS payment_type,
    ptt.stage_productt AS stage_product,
    ptt.consultants_1t AS consultants_1,
    ptt.consulting_role_1t AS consulting_role_1,
    ptt.consultants_2t AS consultants_2,
    ptt.consulting_role_2t AS consulting_role_2,
    ptt.ho_trot AS ho_tro,
    ptt.price_list_idt AS price_list_id,
    ptt.orgcompany_id AS orgcompany_id,
    ptt.company_idt AS company_id,
    ptt.write_date AS write_date,
    ptt.brand_id AS brand_id,
    ptt.brand_etl AS brand_etl
FROM {{ref('stg_pts_stag_payment_all_payment_transfer')}} ptt
UNION ALL
-- Bảng all payment
SELECT 
    ap.id AS id, 
    ap.product_type AS product_type,
    ap.ma_phieu AS ma_phieu,
    ap.crm_id AS crm_id,
    ap.payment_date AS payment_date,
    ap.payment_method AS payment_method,
    ap.communication AS communication,
    ap.clineid AS clineid,
    ap.product_id AS product_id,
    ap.quantity AS quantity,
    ap.uom_price AS uom_price,
    ap.number_used AS number_used,
    ap.total AS total,
    ap.total_received AS total_received,
    ap.total_received_cline AS total_received_cline,
    ap.payment AS payment,
    ap.payment_type AS payment_type,
    ap.stage_product AS stage_product,
    ap.consultants_1 AS consultants_1,
    ap.consulting_role_1 AS consulting_role_1,
    ap.consultants_2 AS consultants_2,
    ap.consulting_role_2 AS consulting_role_2,
    ap.ho_tro AS ho_tro,
    ap.price_list_id AS price_list_id,
    ap.orgcompany_id AS orgcompany_id,
    ap.company_id AS company_id,
    ap.write_date AS write_date,
    ap.brand_id AS brand_id,
    ap.brand_etl AS brand_etl
FROM {{ref('stg_pts_stag_payment_all_payment')}} ap
)
SELECT 
    apat.id::int AS id,
    apat.product_type::text AS product_type,
    apat.ma_phieu::text AS ma_phieu,
    apat.crm_id::int AS crm_id,
    apat.payment_date::date AS payment_date,
    apat.payment_method::text AS payment_method,
    apat.communication::text AS communication,
    apat.clineid::int AS clineid,
    CASE 
        WHEN apat.product_id IS NULL OR apat.product_id = 0 THEN fpi.product_id::int
        ELSE fpi.product_id::int
    END AS product_id,
    apat.quantity::numeric AS quantity,
    apat.uom_price::numeric AS uom_price,
    apat.number_used::numeric AS number_used,
    apat.total::numeric AS total,
    apat.total_received::numeric AS total_received,
    apat.total_received_cline::numeric AS total_received_cline,
    apat.payment::numeric AS payment,
    apat.payment_type::text AS payment_type,
    apat.stage_product::text AS stage_product,
    apat.consultants_1::text AS consultants_1,
    apat.consulting_role_1::text AS consulting_role_1,
    apat.consultants_2::text AS consultants_2,
    apat.consulting_role_2::text AS consulting_role_2,
    apat.ho_tro::text AS ho_tro,
    apat.price_list_id::int AS price_list_id,
    apat.orgcompany_id::int AS orgcompany_id,
    apat.company_id::int AS company_id,
    apat.write_date::timestamp AS write_date,
    apat.brand_id::int AS brand_id,
    apat.brand_etl::int AS brand_etl
FROM all_payment_and_transfer apat
    LEFT JOIN {{ref('stg_pts_stag_payment_fix_product_id')}} fpi ON apat.clineid = fpi.clineid AND apat.brand_id = fpi.brand_id
