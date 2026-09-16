-- Báo cáo doanh số theo mẫu người dùng cung cấp (thay cho bản target đơn giản
-- trước đó). Toàn bộ số liệu KHÔNG bao gồm CBNV (loại nhom_nguon_baocao =
-- 'CBNV' khỏi mọi phép tính, đúng ghi chú "Không bao gồm DS CBNV" trên mẫu).
-- Đã verify khớp khá chính xác với mẫu tháng 8 (nghìn đồng):
--   1   Tổng (trừ CBNV)                     5,253,852
--   1.1 Doanh số dịch vụ                    4,385,727
--   1.2 Doanh số nhà thuốc                    868,125
--   2.1 MD gồm nhà thuốc                    4,003,366
--       MD không gồm nhà thuốc              3,319,932 (= MKT Digital+Seeding+Vãng lai)
--       Nhà thuốc (MD, phần còn lại)          683,434 (= nhà thuốc - nhà thuốc ML)
--   2.2 Nguồn cơ sở                         1,250,486 (= ĐTKD-MGM+Loyalty+38PM+Khác+Nhà thuốc ML)
--       Nhà thuốc (ML)                        184,691
-- LƯU Ý: "Nhà thuốc (MD)"/"Nhà thuốc (ML)" ở đây tính theo CÔNG THỨC PHẦN DƯ
-- (nhà thuốc - nhà thuốc ML = nhà thuốc MD), độc lập với việc bảng chi tiết
-- report_thv_revenue đang để NULL cho các dòng nhà thuốc không rõ nguồn — ở
-- báo cáo tổng hợp này các dòng NULL đó vẫn rơi vào "Nhà thuốc (MD)" (phần
-- dư), giống đúng cách mẫu tính (chỉ có 2 rổ MD/ML cho nhà thuốc, không có ô
-- "không rõ nguồn" riêng).
-- "Khác" = nhóm MO (dịch vụ) — hiện các tháng có dữ liệu đều ra 0, khớp mẫu.
-- "38PM" = nhóm PK38 (dịch vụ).
-- Target: chỉ 4 dòng có target thật (tong/md_gom_nt/md_khong_nt/dtkd_mgm/
-- loyalty/nguon_co_so theo rtr_target); các dòng chi tiết còn lại (MKT
-- Digital/Seeding/Vãng lai/Nhà thuốc MD/38PM/Khác/Nhà thuốc ML) không có
-- target riêng trong kế hoạch gốc -> để NULL, giống mẫu (ô trống).

with combine as (
    select * from {{ ref('rtr_combine') }}
),

cb as (
    -- loại CBNV khỏi toàn bộ báo cáo này theo đúng mẫu
    select * from combine
    where coalesce(nhom_nguon_baocao, '') <> 'CBNV'
),

cbnv_total as (
    -- riêng dòng "3" lấy TỪ combine (chưa loại CBNV) chỉ phần CBNV, cả dịch
    -- vụ lẫn nhà thuốc, đối lập với cb (đã loại CBNV) dùng cho mọi dòng khác.
    select
        date_trunc('month', invoicedate)::date as ngay_dau_thang,
        sum(sotienphieu) as cbnv
    from combine
    where nhom_nguon_baocao = 'CBNV'
    group by 1
),

m as (
    select
        date_trunc('month', invoicedate)::date as ngay_dau_thang,
        sum(sotienphieu) as tong,
        sum(sotienphieu) filter (where nguon_doanh_thu = 'dich_vu') as dich_vu,
        sum(sotienphieu) filter (where nguon_doanh_thu = 'nha_thuoc') as nha_thuoc,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'dich_vu' and nhom_nguon_baocao = 'MD'
        ) as mkt_digital,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'dich_vu' and nhom_nguon_baocao = 'MD_Seeding'
        ) as seeding,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'dich_vu' and nhom_nguon_baocao = 'VL'
        ) as vang_lai,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'dich_vu' and nhom_md_ml_baocao = 'MD'
        ) as md_khong_nt,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'nha_thuoc' and nhom_md_ml_baocao = 'ML'
        ) as nha_thuoc_ml,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'dich_vu' and nhom_nguon_baocao = 'ĐTKD - MGM'
        ) as dtkd_mgm,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'dich_vu' and nhom_nguon_baocao = 'Loyalty'
        ) as loyalty,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'dich_vu' and nhom_nguon_baocao = 'PK38'
        ) as pk38,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'dich_vu' and nhom_nguon_baocao = 'MO'
        ) as khac
    from cb
    group by 1
),

m2 as (
    select
        *,
        coalesce(nha_thuoc, 0) - coalesce(nha_thuoc_ml, 0) as nha_thuoc_md,
        coalesce(md_khong_nt, 0) + (coalesce(nha_thuoc, 0) - coalesce(nha_thuoc_ml, 0)) as md_gom_nt,
        coalesce(dtkd_mgm, 0) + coalesce(loyalty, 0) + coalesce(pk38, 0) + coalesce(khac, 0) + coalesce(nha_thuoc_ml, 0) as nguon_co_so
    from m
),

target_by_month as (
    select
        ngay_dau_thang,
        max(target) filter (where chi_tieu = 'ds') as t_tong,
        max(target) filter (where chi_tieu = 'md') as t_md,
        sum(target) filter (where chi_tieu in ('dtkd', 'mgm')) as t_dtkd_mgm,
        max(target) filter (where chi_tieu = 'loyalty') as t_loyalty,
        max(target) filter (where chi_tieu = 'ml') as t_nguon_co_so
    from {{ ref('rtr_target_latest') }}
    group by 1
),

rows as (
    select m2.ngay_dau_thang, 1  as thu_tu, '1'   as stt, 1 as cap, 'Doanh số Nội soi tiêu hóa Việt'         as noi_dung, t.t_tong        as chi_tieu, m2.tong          as doanh_so_thuc_te, 'Không bao gồm DS CBNV' as ghi_chu from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 2,  '1.1', 2, 'Doanh số dịch vụ',                                    null,            m2.dich_vu,       null from m2
    union all select m2.ngay_dau_thang, 3,  '1.2', 2, 'Doanh số bán SP (nhà thuốc)',                         null,            m2.nha_thuoc,     null from m2
    union all select m2.ngay_dau_thang, 4,  '2',   1, 'Doanh số theo Nguồn',                                 t.t_tong,        m2.tong,          'Không bao gồm DS CBNV' from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 5,  '2.1', 2, 'Nguồn MKT (MD)_gồm nhà thuốc',                        t.t_md,          m2.md_gom_nt,     null from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 6,  '2.1.1',   3, 'Nguồn MKT (MD)_không gồm nhà thuốc',              t.t_md,          m2.md_khong_nt,   null from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 7,  '2.1.1.1', 4, 'MKT Digital',                                     null,            m2.mkt_digital,   null from m2
    union all select m2.ngay_dau_thang, 8,  '2.1.1.2', 4, 'Seeding',                                         null,            m2.seeding,       null from m2
    union all select m2.ngay_dau_thang, 9,  '2.1.1.3', 4, 'Vãng lai',                                        null,            m2.vang_lai,      null from m2
    union all select m2.ngay_dau_thang, 10, '2.1.2',   3, 'Nhà thuốc (MD)',                                  null,            m2.nha_thuoc_md,  null from m2
    union all select m2.ngay_dau_thang, 11, '2.2',     2, 'Nguồn cơ sở',                                     t.t_nguon_co_so, m2.nguon_co_so,   null from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 12, '2.2.1',   3, 'ĐTKD - MGM',                                      t.t_dtkd_mgm,    m2.dtkd_mgm,      null from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 13, '2.2.2',   3, 'Loyalty',                                         t.t_loyalty,     m2.loyalty,       null from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 14, '2.2.3',   3, '38PM',                                            null,            m2.pk38,          null from m2
    union all select m2.ngay_dau_thang, 15, '2.2.4',   3, 'Khác',                                            null,            m2.khac,          null from m2
    union all select m2.ngay_dau_thang, 16, '2.2.5',   3, 'Nhà thuốc (ML)',                                  null,            m2.nha_thuoc_ml,  null from m2
    union all select ngay_dau_thang,     17, '3',      1, 'Doanh số nguồn đối ngoại, CBNV',                  null,            cbnv,             null from cbnv_total
),

grand_total as (
    select ngay_dau_thang, doanh_so_thuc_te as tong_thang
    from rows
    where thu_tu = 1
)

select
    rows.ngay_dau_thang,
    rows.stt,
    rows.cap,
    rows.noi_dung,
    rows.chi_tieu::bigint as chi_tieu,
    rows.doanh_so_thuc_te,
    -- Để dạng tỉ lệ (0-1), KHÔNG nhân 100 -> tool hiển thị tự format %.
    round((rows.doanh_so_thuc_te::numeric / nullif(rows.chi_tieu, 0)), 4) as pct_hoan_thanh,
    -- Dòng "3" (CBNV) là 1 tổng độc lập, không nằm trong tong_thang (đã trừ
    -- CBNV) -> tự so với chính nó, luôn ra 100%.
    case
        when rows.stt = '3' then 1.0
        else round((rows.doanh_so_thuc_te::numeric / nullif(gt.tong_thang::numeric, 0)), 4)
    end as ty_le_dong_gop,
    rows.ghi_chu
from rows
join grand_total gt using (ngay_dau_thang)
order by rows.ngay_dau_thang, rows.thu_tu
