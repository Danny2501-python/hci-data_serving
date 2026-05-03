-- Bang stg_pts_all_payment_transfer: phieu dieu chuyen
WITH result AS (
SELECT ctpl.id,
    ctp.name AS ma_phieu,
    ctp.crm_id,
    CASE WHEN COALESCE(ctpl.from_crm_line_id, 0) = 0 THEN 'cosmetic' ELSE 'service' END product_typef,
    CASE WHEN COALESCE(ctpl.to_crm_line_id, 0) = 0 THEN 'cosmetic' ELSE 'service' END product_typet,
    COALESCE(NULLIF(ctpl.from_crm_line_id, 0), ctpl.from_crm_line_product_id) clineidf,
    COALESCE(NULLIF(ctpl.to_crm_line_id, 0), ctpl.to_crm_line_product_id) clineidt,
    ctp.payment_date,
    ctp.company_id AS orgcompany_id,
    COALESCE(NULLIF(clinef.product_id, 0), clinepf.product_id) AS product_idf,
    COALESCE(NULLIF(clinet.product_id, 0), clinept.product_id) AS product_idt,
    ctpl.from_company_id company_idf,
    COALESCE(NULLIF(ctpl.to_company_id, 0), ctpl.from_company_id) AS company_idt,
    COALESCE(NULLIF(clinef.quantity, 0), clinepf.product_uom_qty) quantityf,
    clinef.uom_price AS uom_pricef,
    COALESCE(NULLIF(clinef.number_used, 0), CASE WHEN clinepf.stage_line_product = 'sold' THEN clinepf.product_uom_qty ELSE 0 END) 
    AS number_usedf,
    COALESCE(clinef.stage, clinepf.stage_line_product) AS stage_productf,
    COALESCE(NULLIF(clinef.consultants_1, 0), clinepf.consultants_1) AS consultants_1f,
    COALESCE(clinef.consulting_role_1, clinepf.consulting_role_1) AS consulting_role_1f,
    COALESCE(NULLIF(clinef.consultants_2, 0), clinepf.consultants_2) AS consultants_2f,
    COALESCE(clinef.consulting_role_2, clinepf.consulting_role_2) AS consulting_role_2f,
    clinef.ho_tro AS ho_trof,
    COALESCE(NULLIF(clinet.quantity, 0), clinept.product_uom_qty) AS quantityt,
    clinet.uom_price AS uom_pricet,
    COALESCE(NULLIF(clinet.number_used, 0), CASE WHEN clinept.stage_line_product = 'sold' THEN clinept.product_uom_qty ELSE 0 END)
    AS number_usedt,
    COALESCE(clinet.stage, clinept.stage_line_product) AS stage_productt,
    COALESCE(NULLIF(clinet.consultants_1, 0), clinept.consultants_1) AS consultants_1t,
    COALESCE(clinet.consulting_role_1, clinept.consulting_role_1) AS consulting_role_1t,
    COALESCE(NULLIF(clinet.consultants_2, 0), clinept.consultants_2) AS consultants_2t,
    COALESCE(clinet.consulting_role_2, clinept.consulting_role_2) AS consulting_role_2t,
    clinet.ho_tro AS ho_trot,
    CASE WHEN clinef.gia_truoc_huy > 0 THEN clinef.gia_truoc_huy ELSE COALESCE(clinef.total, clinepf.total) END AS totalf,
    CASE WHEN clinet.gia_truoc_huy > 0 THEN clinet.gia_truoc_huy
        WHEN clinet.total IS NULL THEN clinept.total ELSE clinet.total
    END AS totalt,
    ctpl.transfer_amount,
    NULL AS payment_type,
    ctpl.total_received AS total_receivedf,
    ctplt.total_received AS total_receivedt,
    clinef.total_received AS total_received_clinef,
    clinet.total_received AS total_received_clinet,
    COALESCE(NULLIF(clinef.price_list_id, 0), clinepf.product_pricelist_id) AS price_list_idf,
    COALESCE(NULLIF(clinet.price_list_id, 0), clinept.product_pricelist_id) AS price_list_idt,
    'pdc' AS payment_method,
    ctp.communication, 
    (ctp.write_date + interval '7 hours') write_date, 
    ctp.brand_id, ctp.brand_etl,
    row_number() over (partition by ctpl.id order by ctpl.id) as rn
   FROM {{source('pre_tns','crm_transfer_payment_line')}} ctpl
     LEFT JOIN {{source('pre_tns','crm_transfer_payment')}} ctp ON ctpl.crm_transfer_payment_id = ctp.id AND ctp.brand_etl = ctpl.brand_etl
     LEFT JOIN {{source('pre_tns','crm_line')}} clinef ON ctpl.from_crm_line_id = clinef.id AND clinef.brand_etl = ctpl.brand_etl
     LEFT JOIN {{source('pre_tns','crm_line')}} clinet ON ctpl.to_crm_line_id = clinet.id AND clinet.brand_etl = ctpl.brand_etl
     LEFT JOIN {{source('pre_tns','crm_line_product')}} clinepf ON ctpl.from_crm_line_product_id = clinepf.id AND clinepf.brand_etl = ctpl.brand_etl
     LEFT JOIN {{source('pre_tns','crm_line_product')}} clinept ON ctpl.to_crm_line_product_id = clinept.id AND clinept.brand_etl = ctpl.brand_etl
     LEFT JOIN {{source('pre_tns','crm_transfer_payment_line')}} ctplt ON ctpl.crm_transfer_payment_id = ctplt.crm_transfer_payment_id 
        AND ctpl.to_crm_line_id = ctplt.from_crm_line_id AND ctplt.brand_etl = ctpl.brand_etl 
  WHERE ctpl.brand_etl IN {{var('all_brand_etl')}} 
      AND ctpl.transfer_amount <> 0 AND ctp.state = 'done' 
      AND ctp.crm_id IN (SELECT crm_id FROM {{ ref('stg_pts_stag_payment_transfer_crm_limit') }} WHERE brand_etl IN {{var('all_brand_etl')}})
)
SELECT 
    rs.id, rs.ma_phieu, rs.crm_id
    , rs.product_typef, rs.product_typet
    , rs.clineidf, rs.clineidt
    , rs.payment_date, rs.orgcompany_id
    , rs.product_idf, rs.product_idt
    , rs.company_idf, rs.company_idt
    , rs.quantityf, rs.uom_pricef, rs.number_usedf, rs.stage_productf
    , rs.consultants_1f, rs.consulting_role_1f, rs.consultants_2f
    , rs.consulting_role_2f, rs.ho_trof
    , rs.quantityt, rs.uom_pricet, rs.number_usedt, rs.stage_productt
    , rs.consultants_1t, rs.consulting_role_1t, rs.consultants_2t
    , rs.consulting_role_2t, rs.ho_trot
    , rs.totalf, rs.totalt, rs.transfer_amount
    , rs.payment_type, rs.total_receivedf, rs.total_receivedt
    , rs.total_received_clinef, rs.total_received_clinet
    , rs.price_list_idf, rs.price_list_idt
    , rs.payment_method
    , rs.communication, rs.write_date
    , rs.brand_id, rs.brand_etl
FROM result rs WHERE rs.rn = 1