-- Doanh số nhóm DỊCH VỤ CHUYÊN KHOA KHÁC — gộp 4 phần theo yêu cầu người dùng.
-- Cột `nguon` để tách lại từng phần, `thang` để cộng theo tháng.
--
--   1. 'San khoa'      : toàn bộ rhh_doanh_so_san_khoa (room 142, đã loại CBNV
--                        và khách có dịch vụ IVF SA_TIENIVF01).
--
--   2. 'Phong khac'    : rhh_doanh_so_phong_khac (các phòng còn lại sau khi
--                        trừ nhóm [TPM] và 4 phòng chuyên khoa), lọc thêm
--                        người giới thiệu: không chứa 'cbnv' và không rỗng —
--                        cùng rule với rhh_doanh_so_san_khoa/ung_buou.
--
--   3. 'Thu khac BHXH' : rhh_thuchi, noidung 'Thu tiền khác (Ghi nhận DS)' VÀ
--                        ghichu chứa 'bao hiem'. Đây đúng là PHẦN BÙ của
--                        rhh_doanh_so_thu_khac (model đó loại ghichu chứa
--                        'bao hiem'/'ksk'), nên 2 model không đếm trùng nhau.
--                        LƯU Ý: ghichu trong dữ liệu viết KHÔNG DẤU
--                        ('BAO HIEM XA HOI ...'), không có bản có dấu.
--
--   4. 'KSK khong nguon': rhh_ehc_payment_service, invoiceremark chứa 'ksk' VÀ
--                        cột nhóm người giới thiệu là NULL. Phần này nằm bên
--                        phiếu viện phí, khác với rhh_doanh_so_ksk (lấy KSK
--                        hợp đồng bên SỔ THU CHI theo noidung).
--
-- KHÔNG chồng lấn giữa 3 phần cùng lấy từ rhh_ehc_payment_service (1, 2, 4):
--   - Phần 1 và 2 đều đòi source_ehc khác NULL/rỗng, trong khi phần 4 đòi cột
--     nhóm là NULL — mà nhóm NULL trùng khớp với source_ehc NULL (đã verify,
--     không có ca "có người giới thiệu nhưng chưa gán nhóm").
--   - Phần 1 lấy room 142, phần 2 đã loại sẵn room 142.
-- Phần 3 lấy từ rhh_thuchi (sổ thu chi) nên độc lập hoàn toàn.
--
-- sotienphieu ở rhh_ehc_payment_service ĐÃ đảo dấu sẵn cho Hoàn tiền/Hoàn ứng
-- nên cộng thẳng; bên rhh_thuchi dùng sotien_thu (heso = 1).
--
-- Không lọc thời gian — phía dùng tự lọc `thang`/`ngay`.

with san_khoa as (
    select
        'San khoa'::text as nguon,
        thang,
        invoicedate as ngay,
        loaiphieu,
        invoiceremark as noidung,
        sophieu,
        patientname as khachhang,
        sotienphieu as sotien
    from {{ ref('rhh_doanh_so_san_khoa') }}
),
phong_khac as (
    select
        'Phong khac'::text as nguon,
        thang,
        invoicedate as ngay,
        loaiphieu,
        invoiceremark as noidung,
        sophieu,
        patientname as khachhang,
        sotienphieu as sotien
    from {{ ref('rhh_doanh_so_phong_khac') }}
    where source_ehc is not null
      and btrim(source_ehc) <> ''
      and source_ehc not ilike '%cbnv%'
),
thu_khac_bhxh as (
    select
        'Thu khac BHXH'::text as nguon,
        date_trunc('month', ngay)::date as thang,
        ngay,
        loaiphieu,
        noidung,
        sophieusothu as sophieu,
        nguoinopnhan as khachhang,
        sotien_thu as sotien
    from {{ ref('rhh_thuchi') }}
    where noidung ilike '%Thu tiền khác (Ghi nhận DS)%'
      and ghichu ilike '%bao hiem%'
),
ksk_khong_nguon as (
    select
        'KSK khong nguon'::text as nguon,
        date_trunc('month', invoicedate)::date as thang,
        invoicedate as ngay,
        loaiphieu,
        invoiceremark as noidung,
        sophieu,
        patientname as khachhang,
        sotienphieu as sotien
    from {{ ref('rhh_ehc_payment_service') }}
    where invoiceremark ilike '%ksk%'
      and dm_hoahongnguoigioithieu_nguoigioithieuname is null
)
select * from san_khoa
union all
select * from phong_khac
union all
select * from thu_khac_bhxh
union all
select * from ksk_khong_nguon
