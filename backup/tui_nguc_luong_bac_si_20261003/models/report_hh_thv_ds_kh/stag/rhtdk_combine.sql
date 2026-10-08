-- Gộp doanh số + mục tiêu của 2 thương hiệu vào 1 bảng (3 model con ở int/:
-- rhtdk_hh, rhtdk_thv_ds, rhtdk_thv_target):
--   - Hồng Hà       (brand_etl = 4): lấy nguyên rhh_ehc_payment_service (đã có
--     sẵn Dịch vụ + Nhà thuốc + Target từ ggs_target_company brand_id = 4).
--   - Tiêu hóa Việt (brand_etl = 8): doanh số từ report_thv_revenue (dịch vụ +
--     nhà thuốc), mục tiêu từ rtr_target_latest (seed rtr_target, bản đang
--     hiệu lực).
--
-- nguon_du_lieu thống nhất 3 giá trị: 'Dịch vụ' / 'Nhà thuốc' / 'Target'
-- (THV đổi từ nguon_doanh_thu dich_vu/nha_thuoc).
--
-- LƯU Ý MỤC TIÊU: THV có nhiều loại chỉ tiêu mỗi tháng (ds, md, ml, dtkd,
-- mgm, loyalty, md_khong_thuoc) — chúng CHỒNG NHAU, không cộng được. Cột
-- loai_chi_tieu cho biết loại; mục tiêu tổng thương hiệu là loai_chi_tieu =
-- 'ds' (HH chỉ có 1 dòng/tháng, cũng gán 'ds'). Khi cộng target tổng phải
-- lọc loai_chi_tieu = 'ds'.
--
-- Cột nguồn:
--   - source_ehc / dm_hoahongnguoigioithieu_nguoigioithieuname: nguồn bên EHC
--     (người giới thiệu / nhóm hoa hồng), cả 2 brand đều có.
--   - erp_source_id_old/old_source_name/erp_source_id_new/new_source_name:
--     nguồn ERP theo id_booking (HH: tên cột gốc; THV: erp_old_*/erp_new_*).
--   - nhom_nguon_baocao/nhom_md_ml_baocao/nguon_sau_mapping: chỉ THV có
--     (HH chưa có bảng nhóm nguồn báo cáo) -> NULL cho HH.
--   - patientcode/invoiceid/pl/roomname/roomname_kb: chỉ HH có -> NULL cho THV.

--
-- Output chỉ giữ các cột báo cáo cần (theo yêu cầu 2026-09-26). Giữ thêm
-- brand_etl/ten_thuong_hieu (phân biệt 2 brand) và loai_chi_tieu (bắt buộc
-- để lọc target 'ds', tránh cộng chồng chỉ tiêu THV).
--   makh           = patientcode (THV lấy từ ehc_tb_patientrecord_thv)
--   phan_loai_coc  = pl (chỉ HH có cọc; THV NULL)
--   nguon_erp      = new_source_name (nguồn mới ERP)
--
-- [2026-09-26] Chỉ tiêu + chi phí ads union thêm dạng dòng, số tiền để ở
-- sotienphieu, invoicedate = ngày đầu tháng:
--   - nguon_du_lieu 'Target', loai_chi_tieu 'ds'  : chỉ tiêu doanh số TỔNG
--     (rhtdk_target). Bỏ Target cũ (dòng Target của rhtdk_hh + toàn bộ
--     rhtdk_thv_target gồm cả md/ml...) — chỉ giữ chỉ tiêu tổng, tránh cộng đôi.
--   - nguon_du_lieu 'Target', loai_chi_tieu 'ads'      : mục tiêu ads tháng
--     (ngày đầu tháng)
--   - nguon_du_lieu 'Target', loai_chi_tieu 'ads_tuan' : mục tiêu ads tuần
--     (ngày đầu tuần theo cột tuan của sheet)
--   - nguon_du_lieu 'Chi phí ads'                      : chi phí ads thực tế
--     THEO NGÀY (invoicedate = ngày chi)
--     (rhtdk_chi_phi_ads, nguồn public.ggs_target_ads_thv_hh).
-- [2026-09-29] HH có thêm 2 khoản TRỪ (sotienphieu âm) từ rhh_ehc_payment_service:
--   nguon_du_lieu 'Túi ngực/mông' / 'Lương bác sĩ', model_nguon 'hh_khoan_tru' —
--   TÁCH RIÊNG, không nằm trong doanh số. Cột bac_si = phẫu thuật viên chính,
--   chỉ có ở dòng 'Lương bác sĩ'.
-- => Cộng doanh số: nguon_du_lieu in ('Dịch vụ','Nhà thuốc'); chỉ tiêu DS:
--    loai_chi_tieu = 'ds'; không cộng lẫn các loại với nhau ('ads' và
--    'ads_tuan' là 2 cách chia cùng 1 ngân sách, không cộng chung).
--
-- [2026-09-26] Lead/booking CRM (crm_lead, active) union thêm dạng dòng, mỗi
-- dòng = 1 lead/booking, sotienphieu NULL -> đếm bằng count(*):
--   - 'SĐT'          : rhtdk_sdt            (type_crm_id 1, ngày tạo)
--   - 'Booking tạo'  : rhtdk_booking_create (type_crm_id 2, ngày tạo)
--   - 'Booking'      : rhtdk_booking        (type_crm_id 2, ngày hẹn)
--   - 'Booking ĐC'   : rhtdk_booking_dc     (type_crm_id 2, ngày đến)
--   sophieu = mã booking/lead (crm_lead.name), makh = mã khách ERP
--   (crm_lead.code_customer, dạng CUS...), tenkh = contact_name,
--   sdt = phone, nguon_erp_cu/nguon_erp = nguồn cũ/mới ERP,
--   nhom_md_ml_baocao gom theo nguồn cũ ERP (xem rhtdk_lead_base).
--   Thêm 2 cột sdt, nguon_erp_cu cho cả dòng doanh số (patientphone,
--   old_source_name).
--
-- [2026-09-26] Chỉ lấy dữ liệu từ 2026-01-01 trở đi (invoicedate >= 2026-01-01)
-- cho mọi loại dòng (doanh số, target, ads, SĐT/booking).

with combine as (
    select * from {{ ref('rhtdk_hh') }}
    where nguon_du_lieu <> 'Target'
    union all
    select * from {{ ref('rhtdk_thv_ds') }}
),

chi_tieu as (
    select
        brand_etl,
        ten_thuong_hieu,
        'Target'::text           as nguon_du_lieu,
        'ds'::text               as loai_chi_tieu,
        ngay_dau_thang           as invoicedate,
        chi_tieu_doanh_so        as sotienphieu
    from {{ ref('rhtdk_target') }}

    union all

    -- Mục tiêu doanh số MD / ML theo tháng (loai_chi_tieu 'md' / 'ml')
    select
        brand_etl,
        ten_thuong_hieu,
        'Target'::text           as nguon_du_lieu,
        loai_chi_tieu,
        ngay_dau_thang           as invoicedate,
        chi_tieu                 as sotienphieu
    from {{ ref('rhtdk_target_md_ml') }}

    union all

    -- Mục tiêu ads tháng: 1 dòng/tháng ở ngày đầu tháng (sheet lặp trên mọi ngày)
    select
        brand_etl,
        ten_thuong_hieu,
        'Target'::text           as nguon_du_lieu,
        'ads'::text              as loai_chi_tieu,
        ngay_dau_thang           as invoicedate,
        max(muc_tieu_thang)      as sotienphieu
    from {{ ref('rhtdk_chi_phi_ads') }}
    group by 1, 2, 5

    union all

    -- Mục tiêu ads tuần: 1 dòng/tuần ở ngày đầu tuần (theo cột tuan của sheet)
    select
        brand_etl,
        ten_thuong_hieu,
        'Target'::text           as nguon_du_lieu,
        'ads_tuan'::text         as loai_chi_tieu,
        min(ngay)                as invoicedate,
        max(muc_tieu_tuan)       as sotienphieu
    from {{ ref('rhtdk_chi_phi_ads') }}
    group by brand_etl, ten_thuong_hieu, ngay_dau_thang, tuan

    union all

    -- Chi phí ads thực tế: theo NGÀY
    select
        brand_etl,
        ten_thuong_hieu,
        'Chi phí ads'::text      as nguon_du_lieu,
        null::text               as loai_chi_tieu,
        ngay                     as invoicedate,
        chi_phi_ads              as sotienphieu
    from {{ ref('rhtdk_chi_phi_ads') }}
),

lead as (
    select 'SĐT'::text as nguon_du_lieu, ngay, booking, contact_name, phone, code_customer, co_line,
           brand_etl, ten_thuong_hieu, source_name, new_source_name, nhom_md_ml_baocao,
           null::numeric as amount_paid
    from {{ ref('rhtdk_sdt') }}
    union all
    select 'Booking tạo'::text, ngay, booking, contact_name, phone, code_customer, null::boolean,
           brand_etl, ten_thuong_hieu, source_name, new_source_name, nhom_md_ml_baocao,
           null::numeric
    from {{ ref('rhtdk_booking_create') }}
    union all
    select 'Booking'::text, ngay, booking, contact_name, phone, code_customer, null::boolean,
           brand_etl, ten_thuong_hieu, source_name, new_source_name, nhom_md_ml_baocao,
           null::numeric
    from {{ ref('rhtdk_booking') }}
    union all
    select 'Booking ĐC'::text, ngay, booking, contact_name, phone, code_customer, null::boolean,
           brand_etl, ten_thuong_hieu, source_name, new_source_name, nhom_md_ml_baocao,
           amount_paid
    from {{ ref('rhtdk_booking_dc') }}
),

gop as (
    select
        brand_etl,
        ten_thuong_hieu,
        nguon_du_lieu,
        loai_chi_tieu,
        invoicedate,
        sophieu,
        sotienphieu,
        patientcode                                  as makh,
        patientname                                  as tenkh,
        patientphone                                 as sdt,
        pl                                           as phan_loai_coc,
        source_ehc                                   as nguon_ehc,
        dm_hoahongnguoigioithieu_nguoigioithieuname  as nhom_nguon_ehc,
        old_source_name                              as nguon_erp_cu,
        new_source_name                              as nguon_erp,
        nhom_md_ml_baocao,
        null::boolean                                as co_line,
        bac_si,
        loai_phau_thuat,
        null::numeric                                as amount_paid
    from combine

    union all

    select
        brand_etl,
        ten_thuong_hieu,
        nguon_du_lieu,
        loai_chi_tieu,
        invoicedate,
        null::text                                   as sophieu,
        sotienphieu,
        null::text                                   as makh,
        null::text                                   as tenkh,
        null::text                                   as sdt,
        null::text                                   as phan_loai_coc,
        null::text                                   as nguon_ehc,
        null::text                                   as nhom_nguon_ehc,
        null::text                                   as nguon_erp_cu,
        null::text                                   as nguon_erp,
        null::text                                   as nhom_md_ml_baocao,
        null::boolean                                as co_line,
        null::text                                   as bac_si,
        null::text                                   as loai_phau_thuat,
        null::numeric                                as amount_paid
    from chi_tieu

    union all

    select
        brand_etl,
        ten_thuong_hieu,
        nguon_du_lieu,
        null::text                                   as loai_chi_tieu,
        ngay                                         as invoicedate,
        booking::text                                as sophieu,
        null::double precision                       as sotienphieu,
        code_customer::text                          as makh,
        contact_name::text                           as tenkh,
        phone::text                                  as sdt,
        null::text                                   as phan_loai_coc,
        null::text                                   as nguon_ehc,
        null::text                                   as nhom_nguon_ehc,
        source_name                                  as nguon_erp_cu,
        new_source_name                              as nguon_erp,
        nhom_md_ml_baocao,
        co_line,
        null::text                                   as bac_si,
        null::text                                   as loai_phau_thuat,
        amount_paid
    from lead
)

select
    brand_etl,
    ten_thuong_hieu,
    -- model int sinh ra dòng (tên bỏ tiền tố rhtdk_), để phân biệt nguồn dữ liệu
    case
        when nguon_du_lieu in ('Dịch vụ', 'Nhà thuốc') and brand_etl = 4 then 'hh'
        when nguon_du_lieu in ('Dịch vụ', 'Nhà thuốc') and brand_etl = 8 then 'thv_ds'
        when nguon_du_lieu in ('Túi ngực/mông', 'Lương bác sĩ') then 'hh_khoan_tru'
        when nguon_du_lieu = 'Target' and loai_chi_tieu = 'ds' then 'target'
        when nguon_du_lieu = 'Target' and loai_chi_tieu in ('md', 'ml') then 'target_md_ml'
        when nguon_du_lieu in ('Target', 'Chi phí ads') then 'chi_phi_ads'
        when nguon_du_lieu = 'SĐT' then 'sdt'
        when nguon_du_lieu = 'Booking tạo' then 'booking_create'
        when nguon_du_lieu = 'Booking' then 'booking'
        when nguon_du_lieu = 'Booking ĐC' then 'booking_dc'
    end::text                                    as model_nguon,
    nguon_du_lieu,
    loai_chi_tieu,
    invoicedate,
    sophieu,
    sotienphieu,
    makh,
    tenkh,
    sdt,
    phan_loai_coc,
    nguon_ehc,
    nhom_nguon_ehc,
    nguon_erp_cu,
    nguon_erp,
    nhom_md_ml_baocao,
    -- [2026-09-29] Nhóm nguồn 5 nhóm để xem tỉ trọng doanh số, CHỈ THV (HH NULL),
    -- chỉ dòng doanh số: Nhà thuốc tách riêng nhóm 'Nhà thuốc'; Dịch vụ gom từ
    -- nhom_nguon_ehc:
    --   'MD - %' -> MD; 'Khách hàng giới thiệu khách hàng' -> MGM; 'CTV%' -> CTV;
    --   '%loyalty%' -> KH cũ; còn lại (N - ..., ML - Display, NULL) -> Khác.
    case
        when brand_etl = 8 and nguon_du_lieu = 'Nhà thuốc' then 'Nhà thuốc'
        when brand_etl = 8 and nguon_du_lieu = 'Dịch vụ' then
            case
                when nhom_nguon_ehc ilike 'MD - %' then 'MD'
                when nhom_nguon_ehc = 'Khách hàng giới thiệu khách hàng' then 'MGM'
                when nhom_nguon_ehc ilike 'CTV%' then 'CTV'
                when nhom_nguon_ehc ilike '%loyalty%' then 'KH cũ'
                else 'Khác'
            end
    end::text                                    as nhom_nguon_ty_trong,
    -- Chỉ dòng SĐT: lead có dịch vụ (HH: crm_lead_product_category_rel, THV:
    -- crm_line) — chỉ đánh dấu; NULL cho booking / doanh số / target / ads.
    co_line,
    -- Chỉ dòng 'Lương bác sĩ' (HH): phẫu thuật viên chính + Đại/Tiểu phẫu; còn lại NULL.
    bac_si,
    loai_phau_thuat,
    -- Chỉ dòng 'Booking ĐC': crm_lead.amount_paid (khách thành công = > 0).
    amount_paid
from gop
where invoicedate >= date '2026-01-01'
