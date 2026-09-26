-- Gộp doanh thu dịch vụ (rtr_ehc_payment_service) và doanh thu nhà thuốc
-- (rtr_ehc_payment_medicine) thành 1 bảng phân tích, giống cách
-- report_thv_sale_online/report_hh_sale_online gộp qua tso_combine/hso_combine.
-- 2 model nguồn đã được thiết kế cùng 1 bộ cột (17 cột, cùng tên/thứ tự) nên
-- union all trực tiếp được, không cần map lại cột.
--
-- Sau union, join thêm rtr_lead (booking bên ERP/CRM) theo id_booking =
-- lead_booking để lấy nguồn ERP (erp_old_source_name/erp_new_source_name, từ
-- crm_lead + m_utm_source_old_new_map). Join an toàn, không fan-out:
-- id_booking luôn dạng "BOOK-..." và trong rtr_lead (brand_etl=8) các dòng
-- dạng "BOOK-..." không trùng mã nào cả.
--
-- nguon_ehc/nguon_erp/nguon_sau_mapping: 3 cột so sánh trực quan. Đối chiếu
-- ERP CHỈ áp dụng cho nguon_doanh_thu = 'dich_vu' — nhà thuốc (nha_thuoc)
-- không map sang crm_lead/m_utm_source_old_new_map.
--
-- nhom_nguon_baocao/nhom_md_ml_baocao HIỆN HÀNH: dùng thẳng tầng EHC
-- (nhom_nguon_baocao_ehc/nhom_md_ml_baocao_ehc) cho CẢ dich_vu lẫn nha_thuoc,
-- cùng 1 rule của rtr_nhom_nguoigioithieu (rule cũ "nhà thuốc có nguồn thì
-- gom hết vào MD" đã bỏ). KHÔNG có nguồn nào cả -> giữ NULL, không đoán (đã
-- thử mặc định VL/MD cho trường hợp này nhưng đối chiếu danh sách MD thật
-- của người dùng thì sai). Riêng nhom_md_ml_baocao: từ T9/2026 VL -> ML (xem
-- select cuối).
--
-- Với dich_vu, nguon_sau_mapping so khớp text erp_old_source_name với
-- dm_hoahongnguoigioithieu_nguoigioithieuname (nhóm người giới thiệu native
-- bên EHC, của CHÍNH dòng đó) — 2 cột này cùng gốc vocab (old_source_name chỉ
-- thêm tiền tố "DG - " ở nhiều dòng, còn lại viết y hệt), nên contains-match
-- đáng tin hơn nhiều so với so khớp thẳng erp_new_source_name (vocab hoàn
-- toàn khác: "Facebook", "Partner_CTV (Cộng tác viên KD)"...).
--   - Khớp (chứa nhau)  -> lấy dm_hoahongnguoigioithieu_nguoigioithieuname
--     (tin EHC, vì bản chất đang nói cùng 1 nguồn).
--   - Không khớp        -> lấy erp_new_source_name (ERP đúng hơn EHC ở đây,
--     xem ví dụ BOOK-260829-00015: EHC ghi "Khách hàng cũ quay lại (loyalty)"
--     nhưng ERP old/new đều chỉ ra Facebook — đã xác nhận với người dùng
--     booking này tính vào nhóm MD).
--   - Không có gì để so (không có booking bên ERP) -> rơi về source_ehc.
--
-- [ĐANG TẮT — tham khảo khi bật lại] Override nhóm theo ERP cho dich_vu. CTE
-- erp_map vẫn được join nhưng KẾT QUẢ KHÔNG DÙNG (xem CTE grouped).
-- nhom_nguon_baocao/nhom_md_ml_baocao (thiết kế override): nguon_sau_mapping đổi nguồn
-- thì nhóm tính theo tên người giới thiệu EHC (nhom_nguon_baocao_ehc/
-- nhom_md_ml_baocao_ehc — vẫn giữ trong bảng, hậu tố "_ehc") không còn đúng
-- nữa cho các dòng lệch — phải map lại theo đúng vocab ERP.
--   - Dòng khớp EHC/không có ERP: giữ nguyên nhom_nguon_baocao_ehc/
--     nhom_md_ml_baocao_ehc cũ (đã đúng).
--   - Dòng lệch (dùng ERP): map qua erp_map bên dưới (18 giá trị
--     erp_new_source_name distinct, brand_etl=8, đối chiếu theo đúng nghĩa
--     với 8 nhóm báo cáo đã có — vd Facebook/Hotline/Tiktok/Youtube/Zalo/
--     Google_Ads/Google_SEO/QR_Event -> MD; Community_Group -> MD_Seeding;
--     Partner_CTV/Partner_B2B/Referral_Customer/Referral_Staff -> ĐTKD-MGM;
--     Return_Customer -> Loyalty; Walk_In -> VL; K_CBNV/K_Đối ngoại/
--     K_Người nhà CBNV -> CBNV). Partner_B2B và QR_Event chưa có tiền lệ dữ
--     liệu cũ để đối chiếu — map theo suy đoán hợp lý nhất, CẦN NGƯỜI DÙNG
--     XÁC NHẬN LẠI nếu 2 giá trị này xuất hiện nhiều.

with combine as (
    select
        'dich_vu' as nguon_doanh_thu,
        *
    from {{ ref('rtr_ehc_payment_service') }}

    union all

    select
        'nha_thuoc' as nguon_doanh_thu,
        *
    from {{ ref('rtr_ehc_payment_medicine') }}
),

lead as (
    select * from {{ ref('rtr_lead') }}
),

joined as (
    select
        combine.*,
        lead.source_id as erp_old_source_id,
        lead.old_source_name as erp_old_source_name,
        lead.new_source_id as erp_new_source_id,
        lead.new_source_name as erp_new_source_name
    from combine
    left join lead on lead.lead_booking = combine.id_booking
),

matched as (
    select
        joined.*,
        (
            joined.erp_old_source_name ilike '%' || joined.dm_hoahongnguoigioithieu_nguoigioithieuname || '%'
            or joined.dm_hoahongnguoigioithieu_nguoigioithieuname ilike '%' || joined.erp_old_source_name || '%'
        ) as ehc_khop_erp_old
    from joined
),

erp_map (erp_new_source_name, nhom_nguon_baocao_erp) as (
    values
    ('Facebook', 'MD'),
    ('Google_Ads', 'MD'),
    ('Google_SEO', 'MD'),
    ('Hotline', 'MD'),
    ('Tiktok', 'MD'),
    ('Youtube', 'MD'),
    ('Zalo', 'MD'),
    ('QR_Event', 'MD'),
    ('Community_Group', 'MD_Seeding'),
    ('K_CBNV', 'CBNV'),
    ('K_Đối ngoại', 'CBNV'),
    ('K_Người nhà CBNV', 'CBNV'),
    ('Partner_CTV (Cộng tác viên KD)', 'ĐTKD - MGM'),
    ('Partner_B2B (Đối tác B2B)', 'ĐTKD - MGM'),
    (E'Referral_Customer\n(KH giới thiệu KH)', 'ĐTKD - MGM'),
    (E'Referral_Staff \n(CBNV giới thiệu KH)', 'ĐTKD - MGM'),
    (E'Return_Customer\n(KH cũ quay lại)', 'Loyalty'),
    ('Walk_In (Vãng lai)', 'VL')
),

grouped as (
    select
        matched.*,
        -- 3 cột để so sánh trực quan: nguồn EHC (native) / nguồn ERP (mới) /
        -- nguồn sau khi mapping. Vẫn tính đủ để tham khảo, nhưng KHÔNG dùng
        -- để suy ra nhom_nguon_baocao/nhom_md_ml_baocao nữa (xem ghi chú dưới).
        matched.dm_hoahongnguoigioithieu_nguoigioithieuname as nguon_ehc,
        matched.erp_new_source_name as nguon_erp,
        case
            when matched.nguon_doanh_thu <> 'dich_vu' then matched.source_ehc
            when matched.ehc_khop_erp_old then matched.dm_hoahongnguoigioithieu_nguoigioithieuname
            else coalesce(matched.erp_new_source_name, matched.source_ehc)
        end as nguon_sau_mapping,
        -- TẠM THỜI (theo yêu cầu) bỏ qua tầng đối chiếu ERP, chỉ tính tới
        -- tầng EHC cho CẢ dich_vu lẫn nha_thuoc — dùng thẳng
        -- nhom_nguon_baocao_ehc/nhom_md_ml_baocao_ehc, KHÔNG mặc định MD nữa
        -- khi không có nguồn (kể cả nha_thuoc) — hoàn toàn không có nguồn thì
        -- giữ NULL, giống nguoigioithieu (source_ehc) cũng đang NULL trong
        -- trường hợp này. Muốn bật lại ERP-override cho dich_vu thì xem lịch
        -- sử git (đã revert phần dùng erp_map ở đây).
        matched.nhom_nguon_baocao_ehc as nhom_nguon_baocao_raw,
        matched.nhom_md_ml_baocao_ehc as nhom_md_ml_baocao_raw
    from matched
    left join erp_map on erp_map.erp_new_source_name = matched.erp_new_source_name
)

select
    grouped.*,
    -- Cột tham chiếu cho dễ check: tên người giới thiệu CÁ NHÂN (khác nguon_ehc
    -- là nhóm hoa hồng native) — cùng giá trị source_ehc, đặt tên rõ nghĩa hơn
    -- để đối chiếu trực tiếp với nguoigioithieuname bên EHC.
    grouped.source_ehc as nguoigioithieu,
    -- Nhóm hoa hồng native (cấp trên của nguoigioithieu, vd nhiều người cùng
    -- thuộc "CTV - Hợp tác") — cùng giá trị nguon_ehc, đặt tên rõ nghĩa hơn.
    grouped.dm_hoahongnguoigioithieu_nguoigioithieuname as nhom_nguoigioithieu,
    -- Hoàn toàn không có nguồn (nguon_ehc/nguoigioithieu NULL) -> giữ NULL,
    -- không đoán/mặc định nhóm nào cả (áp dụng cho cả dich_vu và nha_thuoc).
    grouped.nhom_nguon_baocao_raw as nhom_nguon_baocao,
    -- TỪ T9/2026: nhóm VL ("N - Vãng lai") xếp sang ML thay vì MD (yêu cầu
    -- người dùng). Điều kiện theo invoicedate nên phải đặt ở đây, không đặt ở
    -- rtr_nhom_nguoigioithieu (dimension người giới thiệu, không có ngày).
    -- Tháng <= T8/2026 giữ nguyên VL -> MD như trước.
    case
        when grouped.invoicedate >= date '2026-09-01'
             and grouped.nhom_nguon_baocao_raw = 'VL' then 'ML'
        else grouped.nhom_md_ml_baocao_raw
    end as nhom_md_ml_baocao
from grouped
