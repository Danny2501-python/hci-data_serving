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
-- TỪ T9/2026 quy tắc đổi (chỉ áp cho tháng >= 2026-09, T8 trở về trước giữ
-- nguyên số cũ — chi tiết ở CTE mbc):
--   - Vãng lai không tính vào MD nữa mà chuyển xuống Nguồn cơ sở: dòng 2.1.1
--     thành "MD không chứa vãng lai" (= MKT Digital + Seeding), dòng Vãng lai
--     chuyển từ 2.1.1.3 sang 2.2.4 (ngay sau "Khác"), đẩy "Nhà thuốc (ML)"
--     xuống 2.2.5.
--   - Vãng lai tách đôi: "Vãng lai (dịch vụ)" đứng riêng ở 2.2.4, còn
--     "Vãng lai (nhà thuốc)" (2.2.5.2) cộng vào khối nhà thuốc — trước T9 phần
--     nhà thuốc này nằm trong phần dư "Nhà thuốc (MD)".
--   - Nhóm PK38 ("38PM", dịch vụ) gộp vào "ĐTKD - MGM" (2.2.1) vì họ là CTV
--     đại lý -> từ T9 KHÔNG còn dòng 2.2.3 "38PM", các dòng sau dịch lên 1 bậc
--     (Khác 2.2.3, Vãng lai (dịch vụ) 2.2.4, khối nhà thuốc 2.2.5.x); tháng
--     <= T8 vẫn giữ 38PM ở 2.2.3, Khác 2.2.4, Nhà thuốc (ML) 2.2.5.
--   - Nhà thuốc không có nhóm người giới thiệu (nhom_nguoigioithieu null) tách
--     thành dòng "Thuốc bán lẻ", tính vào Nguồn cơ sở (ML) thay vì rơi vào
--     phần dư "Nhà thuốc (MD)"; "Nhà thuốc (ML)" từ T9 chỉ còn phần nhà thuốc
--     TRUY ĐƯỢC nhóm nguồn ML. 2 khoản này nằm dưới 1 dòng tổng 2.2.5
--     "Nhà thuốc (ML) + Thuốc bán lẻ" (con: 2.2.5.1 nhà thuốc ML, 2.2.5.2
--     vãng lai nhà thuốc, 2.2.5.3 thuốc bán lẻ).
--   => Nguồn cơ sở (ML) từ T9 = ĐTKD-MGM (đã gồm 38PM) + Loyalty + Khác +
--      Vãng lai +
--      [Nhà thuốc (ML) + Thuốc bán lẻ].
-- "Khác" = nhóm MO (dịch vụ) — hiện các tháng có dữ liệu đều ra 0, khớp mẫu.
-- "38PM" = nhóm PK38 (dịch vụ) — chỉ là dòng riêng với tháng <= T8/2026.
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
        -- 3 metric dưới đây liệt kê THẲNG nhom_nguon_baocao thay vì dùng
        -- nhom_md_ml_baocao, vì từ T9/2026 rtr_combine đã xếp VL sang ML —
        -- nếu lọc theo nhom_md_ml_baocao thì số MD/nhà thuốc ML sẽ tự đổi theo
        -- và lệch cách tính của báo cáo này (vãng lai đã có dòng riêng 2.2.4).
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'dich_vu'
              and nhom_nguon_baocao in ('MD', 'MD_Seeding', 'VL')
        ) as md_khong_nt,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'nha_thuoc'
              and nhom_nguon_baocao in ('PK38', 'ĐTKD - MGM', 'Loyalty')
        ) as nha_thuoc_ml,
        -- 3 metric chỉ dùng cho quy tắc từ T9/2026 (xem CTE mbc): nhà thuốc ML
        -- phần TRUY ĐƯỢC nhóm nguồn, nhà thuốc nhóm VL ("N - Vãng lai") tách
        -- riêng thành 1 dòng, và phần hoàn toàn không có nhóm nguồn
        -- (nhom_nguoigioithieu null) = thuốc bán lẻ. Cả 3 đều nằm trong khối
        -- nhà thuốc ở Nguồn cơ sở, không rơi vào phần dư "Nhà thuốc (MD)".
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'nha_thuoc'
              and nhom_nguon_baocao in ('PK38', 'ĐTKD - MGM', 'Loyalty')
              and nhom_nguoigioithieu is not null
        ) as nha_thuoc_ml_co_nguon,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'nha_thuoc' and nhom_nguon_baocao = 'VL'
        ) as vang_lai_nt,
        sum(sotienphieu) filter (
            where nguon_doanh_thu = 'nha_thuoc' and nhom_nguoigioithieu is null
        ) as thuoc_ban_le,
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

mbc as (
    -- Chốt số theo quy tắc của từng giai đoạn. TỪ T9/2026 (theo yêu cầu người
    -- dùng) có 3 thay đổi, tháng <= T8/2026 giữ Y NGUYÊN cách cũ để không lệch
    -- mẫu đã verify:
    --   1. Vãng lai KHÔNG còn tính vào MD nữa mà chuyển xuống Nguồn cơ sở (ML)
    --      -> "MD không gồm nhà thuốc" từ T9 = MKT Digital + Seeding, tức là
    --      doanh số MD KHÔNG chứa vãng lai; dòng "Vãng lai" đổi vị trí từ
    --      2.1.1.3 (dưới MD) sang 2.2.4 (dưới Nguồn cơ sở, ngay sau "Khác").
    --   2. Nhà thuốc không truy được nhóm nguồn (nhom_nguoigioithieu null)
    --      không còn nằm trong phần dư "Nhà thuốc (MD)" mà tách thành dòng
    --      "Thuốc bán lẻ" (2.2.5.3), cũng tính vào Nguồn cơ sở (ML).
    --   3. PK38 (38PM) gộp vào "ĐTKD - MGM" -> cột dtkd_mgm_bc; dòng 38PM
    --      (pk38_bc) chỉ còn dữ liệu ở tháng <= T8/2026.
    -- Các cột hậu tố "_bc" = số dùng cho báo cáo; 3 cột NULL theo giai đoạn
    -- (vang_lai_md/vang_lai_ml/thuoc_ban_le_bc) đi kèm bộ lọc tháng ở CTE rows
    -- nên dòng tương ứng chỉ xuất hiện ở giai đoạn của nó.
    select
        m.*,
        case
            when m.ngay_dau_thang >= date '2026-09-01' then coalesce(m.nha_thuoc_ml_co_nguon, 0)
            else coalesce(m.nha_thuoc_ml, 0)
        end as nha_thuoc_ml_bc,
        case
            when m.ngay_dau_thang >= date '2026-09-01' then coalesce(m.thuoc_ban_le, 0)
        end as thuoc_ban_le_bc,
        -- Vãng lai: trước T9 nằm dưới MD, từ T9 nằm dưới Nguồn cơ sở và tách
        -- đôi — vãng lai DỊCH VỤ đứng riêng, vãng lai NHÀ THUỐC nằm trong khối
        -- nhà thuốc (cộng vào dòng tổng nhà thuốc).
        -- [2026-10-05] Người dùng dời mốc VÃNG LAI sang T10/2026 (T9 vẫn tính
        -- MD); thuốc bán lẻ + gộp PK38 vẫn giữ mốc T9.
        case
            when m.ngay_dau_thang < date '2026-10-01' then m.vang_lai
        end as vang_lai_md,
        case
            when m.ngay_dau_thang >= date '2026-10-01' then coalesce(m.vang_lai, 0)
        end as vang_lai_ml,
        case
            when m.ngay_dau_thang >= date '2026-10-01' then coalesce(m.vang_lai_nt, 0)
        end as vang_lai_nt_bc,
        -- md_khong_nt (CTE m) cố ý vẫn gồm VL để giữ số các tháng cũ
        -- -> từ T9 phải trừ vãng lai ra.
        case
            when m.ngay_dau_thang >= date '2026-10-01'
            then coalesce(m.md_khong_nt, 0) - coalesce(m.vang_lai, 0)
            else coalesce(m.md_khong_nt, 0)
        end as md_khong_nt_bc,
        -- Từ T9/2026 PK38 (38PM) gộp vào "ĐTKD - MGM" vì họ là CTV đại lý
        -- -> dòng 2.2.3 "38PM" biến mất từ T9, tháng <= T8 giữ nguyên tách đôi.
        case
            when m.ngay_dau_thang >= date '2026-09-01'
            then coalesce(m.dtkd_mgm, 0) + coalesce(m.pk38, 0)
            else coalesce(m.dtkd_mgm, 0)
        end as dtkd_mgm_bc,
        case
            when m.ngay_dau_thang < date '2026-09-01' then m.pk38
        end as pk38_bc
    from m
),

m2 as (
    select
        mbc.*,
        coalesce(nha_thuoc, 0) - nha_thuoc_ml_bc - coalesce(thuoc_ban_le_bc, 0) - coalesce(vang_lai_nt_bc, 0) as nha_thuoc_md,
        md_khong_nt_bc + (coalesce(nha_thuoc, 0) - nha_thuoc_ml_bc - coalesce(thuoc_ban_le_bc, 0) - coalesce(vang_lai_nt_bc, 0)) as md_gom_nt,
        coalesce(dtkd_mgm, 0) + coalesce(loyalty, 0) + coalesce(pk38, 0) + coalesce(khac, 0) + nha_thuoc_ml_bc + coalesce(thuoc_ban_le_bc, 0) + coalesce(vang_lai_ml, 0) + coalesce(vang_lai_nt_bc, 0) as nguon_co_so
    from mbc
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
    union all select m2.ngay_dau_thang, 6,  '2.1.1',   3, 'Nguồn MKT (MD)_không gồm nhà thuốc',              t.t_md,          m2.md_khong_nt_bc,  null from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 7,  '2.1.1.1', 4, 'MKT Digital',                                     null,            m2.mkt_digital,   null from m2
    union all select m2.ngay_dau_thang, 8,  '2.1.1.2', 4, 'Seeding',                                         null,            m2.seeding,       null from m2
    -- Vãng lai chỉ còn nằm dưới MD với tháng <= T8/2026 (từ T9 xem dòng 2.2.6).
    union all select m2.ngay_dau_thang, 9,  '2.1.1.3', 4, 'Vãng lai',                                        null,            m2.vang_lai_md,   null from m2 where m2.ngay_dau_thang < date '2026-10-01'
    union all select m2.ngay_dau_thang, 10, '2.1.2',   3, 'Nhà thuốc (MD)',                                  null,            m2.nha_thuoc_md,  null from m2
    union all select m2.ngay_dau_thang, 11, '2.2',     2, 'Nguồn cơ sở',                                     t.t_nguon_co_so, m2.nguon_co_so,   null from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 12, '2.2.1',   3, 'ĐTKD - MGM',                                      t.t_dtkd_mgm,    m2.dtkd_mgm_bc,   null from m2 join target_by_month t using (ngay_dau_thang)
    union all select m2.ngay_dau_thang, 13, '2.2.2',   3, 'Loyalty',                                         t.t_loyalty,     m2.loyalty,       null from m2 join target_by_month t using (ngay_dau_thang)
    -- 38PM chỉ còn là dòng riêng với tháng <= T8/2026; từ T9 đã nằm trong 2.2.1.
    union all select m2.ngay_dau_thang, 14, '2.2.3',   3, '38PM',                                            null,            m2.pk38_bc,       null from m2 where m2.ngay_dau_thang < date '2026-09-01'
    union all select m2.ngay_dau_thang, 15, case when m2.ngay_dau_thang >= date '2026-09-01' then '2.2.3' else '2.2.4' end, 3, 'Khác',                                            null,            m2.khac,          null from m2
    -- Từ T9/2026: "Vãng lai" đứng ngay sau "Khác" (cùng cấp), rồi tới 1 dòng
    -- TỔNG nhà thuốc ML + thuốc bán lẻ (2.2.6) với 2 dòng con 2.2.6.1/2.2.6.2
    -- -> tổng 2.2 = 2.2.1..2.2.5 + 2.2.6, không cộng trùng. Các tháng <= T8
    -- giữ nguyên "Nhà thuốc (ML)" ở 2.2.5 cấp 3, không có dòng tổng/bán lẻ.
    union all select m2.ngay_dau_thang, 16, '2.2.4',   3, 'Vãng lai (dịch vụ)',                              null,            m2.vang_lai_ml,   null from m2 where m2.ngay_dau_thang >= date '2026-10-01'
    -- T9/2026 (Vãng lai còn ở MD, 38PM đã gộp) không có dòng 2.2.4 -> khối nhà
    -- thuốc ML đánh số lùi lên 2.2.4 / 2.2.4.1 / 2.2.4.2 cho liền mạch.
    union all select m2.ngay_dau_thang, 17, case when m2.ngay_dau_thang < date '2026-10-01' then '2.2.4' else '2.2.5' end, 3, 'Nhà thuốc (ML) + Thuốc bán lẻ',                   null,            nha_thuoc_ml_bc + coalesce(m2.vang_lai_nt_bc, 0) + coalesce(m2.thuoc_ban_le_bc, 0), null from m2 where m2.ngay_dau_thang >= date '2026-09-01'
    union all select m2.ngay_dau_thang, 18, case when m2.ngay_dau_thang >= date '2026-10-01' then '2.2.5.1' when m2.ngay_dau_thang >= date '2026-09-01' then '2.2.4.1' else '2.2.5' end, case when m2.ngay_dau_thang >= date '2026-09-01' then 4 else 3 end, 'Nhà thuốc (ML)', null, m2.nha_thuoc_ml_bc, null from m2
    union all select m2.ngay_dau_thang, 19, '2.2.5.2', 4, 'Vãng lai (nhà thuốc)',                            null,            m2.vang_lai_nt_bc, null from m2 where m2.ngay_dau_thang >= date '2026-10-01'
    union all select m2.ngay_dau_thang, 20, case when m2.ngay_dau_thang < date '2026-10-01' then '2.2.4.2' else '2.2.5.3' end, 4, 'Thuốc bán lẻ',                                    null,            m2.thuoc_ban_le_bc, null from m2 where m2.ngay_dau_thang >= date '2026-09-01'
    union all select ngay_dau_thang,     21, '3',      1, 'Doanh số nguồn đối ngoại, CBNV',                  null,            cbnv,             null from cbnv_total
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
