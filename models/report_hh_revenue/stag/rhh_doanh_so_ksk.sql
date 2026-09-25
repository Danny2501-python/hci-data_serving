-- Doanh số khám sức khỏe (KSK) — gộp 2 phần theo yêu cầu người dùng:
--
--   1. 'KSK'  : khoản thu KSK ghi qua SỔ THU CHI (rhh_thuchi), lọc
--               noidung ilike '%ksk%'. Chỉ nhánh phiếu thu/chi tay
--               (ehc_tb_phieuthuchi) mới có noidung tự do khớp được — 5 nhánh
--               còn lại noidung là chuỗi cố định ('Thu tiền', 'Thu tiền nhà
--               thuốc', 'Chi bác sĩ...') nên không bao giờ dính 'ksk'.
--               Lấy sotien_thu (heso = 1). Đã kiểm T7/2026: không có cách viết
--               nào khác bị bỏ sót — chỉ có thêm 'Chi trung tâm khám sức khoẻ'
--               nhưng đó là khoản CHI (sotien_thu = 0), không phải doanh số.
--
--   2. 'NGT chưa gán nhóm' : doanh thu bên rhh_ehc_payment_service của các
--               phiếu KHÔNG xác định được nhóm người giới thiệu
--               (dm_hoahongnguoigioithieu_nguoigioithieuname is null).
--               Đã kiểm: cột này null trùng đúng với source_ehc null (không có
--               ca "có người giới thiệu nhưng chưa gán nhóm"), và source_ehc
--               không có giá trị rỗng/khoảng trắng nên lọc `is null` là đủ.
--               sotienphieu ở model đó ĐÃ đảo dấu sẵn cho Hoàn tiền/Hoàn ứng
--               (dm_invoice_typeid 2/4) nên cộng thẳng ra doanh thu ròng.
--
-- 2 phần này không chồng lấn: phần 1 lấy từ ehc_tb_phieuthuchi (sổ thu chi
-- tay), phần 2 lấy từ ehc_tb_invoice/ehc_tb_invoicerequest (phiếu viện phí).
--
-- Trả về chi tiết từng dòng + cột `nguon` để tách 2 phần, `thang` để cộng
-- theo tháng. Không lọc thời gian — phía dùng tự lọc `thang`/`ngay`.

with ksk as (
    select
        'KSK'::text as nguon,
        date_trunc('month', ngay)::date as thang,
        ngay,
        loaiphieu,
        noidung,
        sophieusothu as sophieu,
        nguoinopnhan as khachhang,
        sotien_thu as sotien
    from {{ ref('rhh_thuchi') }}
    where noidung ilike '%ksk%'
),
ngt_chua_gan_nhom as (
    select
        'NGT chưa gán nhóm'::text as nguon,
        date_trunc('month', invoicedate)::date as thang,
        invoicedate as ngay,
        loaiphieu,
        source_ehc as noidung,
        sophieu,
        patientname as khachhang,
        sotienphieu as sotien
    from {{ ref('rhh_ehc_payment_service_base') }}
    where dm_hoahongnguoigioithieu_nguoigioithieuname is null
)
select * from ksk
union all
select * from ngt_chua_gan_nhom
