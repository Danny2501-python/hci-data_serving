-- Mục tiêu các chỉ số marketing (SM) theo tháng — hiện chỉ Tiêu hóa Việt
-- (brand_etl = 8), từ Google Sheet tab ggs_target_sm_thv. 1 dòng = 1 tháng x
-- 1 brand x 1 chỉ số (ma_chi_tieu / ten_chi_tieu / muc_tieu).
--
-- Nguồn: ưu tiên bảng DB public.ggs_target_sm_thv nếu đã đồng bộ; chưa có thì
-- dùng seed seed_ggs_target_sm_thv (chép tay từ sheet). Đồng bộ xong chỉ cần
-- dbt run lại, không phải sửa code.
--
-- Có 2 loại chỉ số, KHÔNG cộng lẫn:
--   - số lượng / tiền (chi_phi_ads, inbox_moi, sdt_tho, sdt_verify, booking_tao,
--     lich_hen_bk_date, khach_den_cua, khach_thanh_cong, doanh_so_mkt_khong_thuoc)
--   - tỷ lệ / đơn giá (ty_le_*, cpi, cpl_*, cpb, cpo, cac, doanh_so_tb_kh,
--     roi_ky_vong) -> chỉ so sánh, không sum qua tháng/brand.

{%- set db_rel = adapter.get_relation(database=target.database, schema='public', identifier='ggs_target_sm_thv') %}

select
    t.brand_etl::integer                    as brand_etl,
    case t.brand_etl::integer
        when 4 then 'Hồng Hà'
        when 8 then 'Tiêu hóa Việt'
    end::text                               as ten_thuong_hieu,
    t.thang::date                           as ngay_dau_thang,
    t.ma_chi_tieu::text                     as ma_chi_tieu,
    t.ten_chi_tieu::text                    as ten_chi_tieu,
    t.muc_tieu::double precision            as muc_tieu
{%- if db_rel %}
from {{ db_rel }} t
{%- else %}
from {{ ref('seed_ggs_target_sm_thv') }} t
{%- endif %}
where t.ma_chi_tieu is not null
