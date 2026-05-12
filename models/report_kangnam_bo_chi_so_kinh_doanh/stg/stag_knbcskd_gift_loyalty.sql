--- Bảng phụ check Booking có sử dụng Quà tặng thẻ thành viên KH loyalty?
SELECT DISTINCT ON (crm_id, brand_etl) 
	lkh.crm_id, lkh.brand_etl, lkd.name loyalty_discount, lkd.type_gift
FROM 
    {{source('kangnam_chi_so_kinh_doanh', 'loyalty_kangnam_history')}} lkh 
    LEFT JOIN {{source('kangnam_chi_so_kinh_doanh', 'loyalty_kangnam_discount')}} lkd 
        on lkh.loyalty_discount = lkd.id 
        and lkh.brand_etl = lkd.brand_etl
WHERE 
    lkh.stage = 'used' AND lkh.brand_etl = 1