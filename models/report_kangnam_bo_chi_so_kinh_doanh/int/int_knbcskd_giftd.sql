--- Bảng phụ Booking áp dụng Quà tặng Loyalty (Voucher + Cấu hình hạng thẻ TV)
SELECT DISTINCT ON (crm_id, brand_etl) 
	cv.crm_id, cv.brand_etl, cvp.name AS loyalty_discount, cvp.apply_for AS type_gift
FROM {{source('kangnam_chi_so_kinh_doanh', 'crm_voucher')}} cv 
LEFT JOIN {{source('kangnam_chi_so_kinh_doanh', 'crm_voucher_program')}} cvp on cv.voucher_program_id = cvp.id and cvp.brand_etl = cvp.brand_etl 
LEFT JOIN {{ref('stag_knbcskd_gift_loyalty')}} gl ON cv.crm_id = gl.crm_id AND cv.brand_etl = gl.brand_etl
WHERE cvp.name ~* 'QUÀ TẶNG LOAL' AND gl.crm_id IS NULL
UNION ALL 
SELECT * FROM {{ref('stag_knbcskd_gift_loyalty')}} gl 