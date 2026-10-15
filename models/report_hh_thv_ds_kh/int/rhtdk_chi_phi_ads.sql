-- Chi phí ads THEO NGÀY theo thương hiệu (Hồng Hà brand_etl = 4, Tiêu hóa
-- Việt brand_etl = 8), giữ đủ mục tiêu tuần/tháng của sheet.
-- Nguồn: public.ggs_target_ads_thv_hh (đồng bộ từ Google Sheet tab
-- ggs_target_ads_thv_hh). Cột date là TEXT dạng dd/mm/yyyy -> to_date(), không
-- ép ::date (DateStyle MDY sẽ hiểu sai/lỗi từ ngày 13).
--
-- 1 dòng = 1 ngày x 1 brand (giữ nguyên dòng gốc, không gộp):
--   chi_phi_ads      : chi phí thực tế CỦA NGÀY -> cộng được.
--   muc_tieu_tuan    : lặp lại trên mọi ngày của tuần  -> KHÔNG cộng.
--   muc_tieu_thang   : lặp lại trên mọi ngày của tháng -> KHÔNG cộng.
-- Tuần là theo cột tuan của sheet (mỗi brand chia tuần có thể khác nhau,
-- vd T9/2026 HH có Tuần 5, THV không).

-- inbox_moi: số inbox mới THEO NGÀY (cộng được), cột inbox của bảng DB
-- (đã đồng bộ từ sheet từ 2026-10-07; trước đó tạm lấy từ seed).

select
    a.brand_etl::integer                        as brand_etl,
    case a.brand_etl
        when 4 then 'Hồng Hà'
        when 8 then 'Tiêu hóa Việt'
    end::text                                   as ten_thuong_hieu,
    to_date(a.date, 'DD/MM/YYYY')               as ngay,
    extract(year from to_date(a.date, 'DD/MM/YYYY'))::integer  as nam,
    extract(month from to_date(a.date, 'DD/MM/YYYY'))::integer as thang,
    a.tuan::text                                as tuan,
    date_trunc('month', to_date(a.date, 'DD/MM/YYYY'))::date   as ngay_dau_thang,
    a.chi_phi::double precision                 as chi_phi_ads,
    a.muc_tieu_tuan::double precision           as muc_tieu_tuan,
    a.muc_tieu_thang::double precision          as muc_tieu_thang,
    a.inbox::double precision                   as inbox_moi
from {{ source('rhh_base', 'ggs_target_ads_thv_hh') }} a
