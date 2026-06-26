-- data_sankey_1.sql → dbt mart
-- Chỉ thay func_data_vong_doi_khach_hang bằng ref('mart_rvdkk_vong_doi')

(
with data_final as (
select
	id_lead, 
	partner_id ,
	booking ,
	ten_kh ,
	ma_kh ,
	phone ,
	chinhanh_id_book,
	nhom_nguon,
	nguon_booking,
	ngay_den_cua,
	trang_thai_book,
	brand_id_book,
	type_crm_id,
	crm_type,
	id_line,
	product_id,
	trang_thai_dv,
	product,
	product_category,
	id_tt,
	ma_phieu,
	doanh_so,
	ngay_tt,
	chinhanh_tt,
	tu_van1_id,
	tu_van1,
	pb_tu_van1,
	pb_tu_van1_id,
	total_received,
	dv_tc,
	chi_nhanh,
	tong_da_nhan_book,
	book_tc,
	ma_kh_new,
	rnk,
	ngay_dc_truoc,
	kh_tv,
	check_tv_rk1,
	check_rnk_ago,
	stt ,
	final_result,
	case
		when id_lead = 1430632 then 1
		else brand_id
	end as brand_id,
	case
		when id_lead = 1430632 then 'Kangnam'
		else thuong_hieu
	end as thuong_hieu,
        'data_goc' as data_type,
        his_service_type,
        min_dc
from
	{{ ref('mart_rvdkk_vong_doi') }}
)
select * from data_final	
where brand_id = 1
and dv_tc = 'DV thành công'
and booking not in ('BOOK-220507-00429','BOOK-221106-00350')
and date(min_dc) >= '20220601'
)
union all 
(
with data_final as (
select
	id_lead, 
	partner_id ,
	booking ,
	ten_kh ,
	ma_kh ,
	phone ,
	chinhanh_id_book,
	nhom_nguon,
	nguon_booking,
	ngay_den_cua,
	trang_thai_book,
	brand_id_book,
	type_crm_id,
	crm_type,
	id_line,
	product_id,
	trang_thai_dv,
	product,
	product_category,
	id_tt,
	ma_phieu,
	doanh_so,
	ngay_tt,
	chinhanh_tt,
	tu_van1_id,
	tu_van1,
	pb_tu_van1,
	pb_tu_van1_id,
	total_received,
	dv_tc,
	chi_nhanh,
	tong_da_nhan_book,
	book_tc,
	ma_kh_new,
	rnk,
	ngay_dc_truoc,
	kh_tv,
	check_tv_rk1,
	check_rnk_ago,
	stt ,
	final_result,
	case
		when id_lead = 1430632 then 1
		else brand_id
	end as brand_id,
	case
		when id_lead = 1430632 then 'Kangnam'
		else thuong_hieu
	end as thuong_hieu,
        'data_duplicate' as data_type,
        his_service_type,
        min_dc
from
	{{ ref('mart_rvdkk_vong_doi') }}
)
select * from data_final	
where brand_id = 1
and dv_tc = 'DV thành công'
and booking not in ('BOOK-220507-00429','BOOK-221106-00350')
and date(min_dc) >= '20220601'
)
