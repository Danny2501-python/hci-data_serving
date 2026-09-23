-- Bảng CHI TIẾT TỪNG PHIẾU gộp toàn bộ model doanh số Hồng Hà, mỗi cục gắn tag
-- `nhom` để cộng/tách tuỳ ý. Materialize ra bảng nên query thẳng được.
--
-- KHÔNG gộp 2 model là roll-up của model khác (sẽ đếm trùng):
--   - rhh_doanh_so_chuyen_khoa_khac : ghép lại từ san_khoa + phong_khac +
--     rhh_thuchi(BHXH) + KSK không nguồn.
--   - rhh_doanh_so_lgbt_erp         : union của lgbt_erp_hh + lgbt_erp_vpth
--     (2 model con ĐÃ có trong bảng này).
--
-- 6 cục lấy từ rhh_ehc_payment_service (TPM / PTTM / LGBT / Sản / Ung bướu /
-- Phòng khác) KHÔNG phủ kín 100% viện phí: 4 model chuyên khoa có bộ lọc riêng
-- (bỏ CBNV, bỏ nguồn rỗng) trong khi Phòng khác đã loại sẵn 4 phòng đó, nên
-- vài phiếu rơi ra ngoài (T8/2026: 1 phiếu 267.537,31 của NGUYỄN THỊ PHƯỢNG,
-- phòng Sản, nguồn 'K - CBNV'). Muốn ra đúng tổng viện thì dùng
-- rhh_ehc_payment_service_test, không cộng bảng này.
--
-- la_coc: EHC lấy theo pl = 'Cọc trong tháng'; ERP lấy cột la_coc sẵn có; nhà
-- thuốc / sổ thu chi luôn false. Cộng LGBT từ 2 nguồn EHC + ERP phải trừ cọc
-- một bên vì khoản CUST.IN có ở cả hai.
--
-- Đối chiếu T8/2026 (xem comment từng model con để biết cách lọc):
--   TPM 12.850.342.614,85 | Phòng khác 364.441.421,64 | Ung bướu 442.417.092,20
--   LGBT EHC 310.170.000 (gồm cọc 2.500.000) | LGBT ERP 311.555.000
--   Nhà thuốc 202.897.610 | KSK 185.014.000 | Thu khác 165.000.000
--   PTTM EHC 48.000.000 | Sản khoa 7.616.400

-- NGUỒN ERP (erp_source_*): id_booking -> crm_lead (brand_etl = 4) -> lấy
-- crm_lead.source_id (ĐÂY LÀ ID CŨ: 8.617 lead brand 4 khớp
-- utm_source_old_source_rel.old_source_id, 0 lead khớp .source_id) -> giải tên
-- trong utm_source brand_etl = 4.
--
-- new_source_name: id mới lấy qua utm_source_old_source_rel (old_source_id =
-- crm_lead.source_id), rồi giải tên CŨNG TRONG brand_etl = 4.
-- HIỆN TẠI CỘT NÀY NULL 100% và đó là ĐÚNG: brand 4 không có dòng nào trong
-- dải id 686-712 (danh mục nguồn mới của Hồng Hà chưa được ERP đồng bộ sang
-- utm_source). Kiểm chứng: crm_lead.new_source_id cũng vậy — 2.269 lead brand 4
-- có giá trị, giải được ở brand 4 là 0, ở brand 8 là 2.269, và 2 nguồn khớp
-- nhau 100%.
-- CỐ Ý KHÔNG lấy tên từ brand 8: đó là danh mục của pháp nhân khác, lệch đúng
-- 1 vị trí so với Hồng Hà (id 687 ở brand 8 = 'Instagram' trong khi nguồn cũ
-- tương ứng là 'MD - Facebook'). Khi ERP đẩy danh mục mới cho brand 4, chạy
-- lại model là tên tự hiện, không phải sửa code.
--
-- Áp cho MỌI nhóm có id_booking: các nhóm EHC lấy booking từ hồ sơ bệnh nhân,
-- các nhóm ERP lấy từ cột booking của phiếu. Nhà thuốc / KSK / Thu khác không
-- có id_booking nên 2 cột này luôn NULL. Nhóm LGBT - ERP VP Thương hiệu cũng
-- NULL vì booking của họ nằm ở crm_lead brand_etl = 1, không phải 4.

with lead_dedup as (
    select distinct on (l.name)
           l.name      as id_booking,
           l.source_id as erp_source_id_old
    from {{ source('rhh_base', 'crm_lead') }} l
    where l.brand_etl = 4
      and coalesce(btrim(l.name), '') <> ''
    order by l.name, l.write_date desc nulls last, l.id desc
),

rel as (
    select u.old_source_id, u.source_id
    from {{ source('rhh_base', 'utm_source_old_source_rel') }} u
    where u.source_server = 'hh'
      and u.brand_etl = 4
),

us as (
    select id, name
    from {{ source('rhh_base', 'utm_source') }}
    where brand_etl = 4
),

ehc as (
    select 'TPM - Thuê phòng mổ'::text as nhom, null::text as nhom_con,
           'rhh_doanh_so_tpm'::text as model,
           date_trunc('month', invoicedate)::date as thang, invoicedate as ngay,
           sophieu, loaiphieu, invoiceremark as noidung, patientname as khachhang,
           patientcode, patientphone, id_booking, source_ehc,
           dm_hoahongnguoigioithieu_nguoigioithieuname as nhom_nguon,
           roomid, roomid_kb, invoiceid, pl = 'Cọc trong tháng' as la_coc,
           sotienphieu as sotien
    from {{ ref('rhh_doanh_so_tpm') }}

    union all
    select 'PTTM - EHC', null, 'rhh_doanh_so_pttm', thang, invoicedate,
           sophieu, loaiphieu, invoiceremark, patientname, patientcode, patientphone,
           id_booking, source_ehc, dm_hoahongnguoigioithieu_nguoigioithieuname,
           roomid, roomid_kb, invoiceid, pl = 'Cọc trong tháng', sotienphieu
    from {{ ref('rhh_doanh_so_pttm') }}

    union all
    select 'LGBT - EHC', null, 'rhh_doanh_so_lgbt', thang, invoicedate,
           sophieu, loaiphieu, invoiceremark, patientname, patientcode, patientphone,
           id_booking, source_ehc, dm_hoahongnguoigioithieu_nguoigioithieuname,
           roomid, roomid_kb, invoiceid, pl = 'Cọc trong tháng', sotienphieu
    from {{ ref('rhh_doanh_so_lgbt') }}

    union all
    select 'Sản khoa', null, 'rhh_doanh_so_san_khoa', thang, invoicedate,
           sophieu, loaiphieu, invoiceremark, patientname, patientcode, patientphone,
           id_booking, source_ehc, dm_hoahongnguoigioithieu_nguoigioithieuname,
           roomid, roomid_kb, invoiceid, pl = 'Cọc trong tháng', sotienphieu
    from {{ ref('rhh_doanh_so_san_khoa') }}

    union all
    select 'Ung bướu', null, 'rhh_doanh_so_ung_buou', thang, invoicedate,
           sophieu, loaiphieu, invoiceremark, patientname, patientcode, patientphone,
           id_booking, source_ehc, dm_hoahongnguoigioithieu_nguoigioithieuname,
           roomid, roomid_kb, invoiceid, pl = 'Cọc trong tháng', sotienphieu
    from {{ ref('rhh_doanh_so_ung_buou') }}

    union all
    select 'Phòng khác', null, 'rhh_doanh_so_phong_khac', thang, invoicedate,
           sophieu, loaiphieu, invoiceremark, patientname, patientcode, patientphone,
           id_booking, source_ehc, dm_hoahongnguoigioithieu_nguoigioithieuname,
           roomid, roomid_kb, invoiceid, pl = 'Cọc trong tháng', sotienphieu
    from {{ ref('rhh_doanh_so_phong_khac') }}
),

erp as (
    select 'LGBT - ERP Hồng Hà'::text as nhom, phap_nhan as nhom_con,
           'rhh_doanh_so_lgbt_erp_hh'::text as model,
           thang, ngay, ma_phieu as sophieu, payment_type as loaiphieu,
           product as noidung, khachhang, null::text as patientcode, phone as patientphone,
           booking as id_booking, source as source_nguon, category_source as nhom_nguon,
           null::integer as roomid, null::integer as roomid_kb, null::integer as invoiceid,
           la_coc, sotien
    from {{ ref('rhh_doanh_so_lgbt_erp_hh') }}

    union all
    select 'LGBT - ERP VP Thương hiệu', phap_nhan, 'rhh_doanh_so_lgbt_erp_vpth',
           thang, ngay, ma_phieu, payment_type, product, khachhang, null, phone,
           booking, source, category_source, null, null, null, la_coc, sotien
    from {{ ref('rhh_doanh_so_lgbt_erp_vpth') }}

    union all
    select 'PTTM - ERP', phap_nhan, 'rhh_doanh_so_pttm_erp',
           thang, ngay, ma_phieu, payment_type, product, khachhang, null, phone,
           booking, source, category_source, null, null, null, la_coc, sotien
    from {{ ref('rhh_doanh_so_pttm_erp') }}
),

khac as (
    select 'Nhà thuốc'::text as nhom, null::text as nhom_con,
           'rhh_doanh_so_nha_thuoc'::text as model,
           thang, ngay, sophieu, 'Thu tiền nhà thuốc'::text as loaiphieu,
           ghichu as noidung, coalesce(patientname, khachhang) as khachhang,
           patientcode, patientphone, null::text as id_booking, source_ehc,
           dm_hoahongnguoigioithieu_nguoigioithieuname as nhom_nguon,
           null::integer as roomid, null::integer as roomid_kb, null::integer as invoiceid,
           false as la_coc, sotienphieu as sotien
    from {{ ref('rhh_doanh_so_nha_thuoc') }}

    union all
    select 'Khám sức khỏe', nguon, 'rhh_doanh_so_ksk',
           thang, ngay, sophieu, loaiphieu, noidung, khachhang,
           null, null, null, null, null, null, null, null, false, sotien
    from {{ ref('rhh_doanh_so_ksk') }}

    union all
    select 'Thu khác', hinhthucthu, 'rhh_doanh_so_thu_khac',
           thang, ngay, sophieu, loaiphieu, noidung, nguoinop,
           null, null, null, null, ghichu, null, null, null, false, sotien
    from {{ ref('rhh_doanh_so_thu_khac') }}
),

gop as (
    select * from ehc
    union all
    select * from erp
    union all
    select * from khac
)

select
    gop.*,
    ld.erp_source_id_old,
    us_old.name   as old_source_name,
    rel.source_id as erp_source_id_new,
    us_new.name   as new_source_name
from gop
left join lead_dedup ld on ld.id_booking = gop.id_booking
left join rel           on rel.old_source_id = ld.erp_source_id_old
left join us us_old     on us_old.id = ld.erp_source_id_old
left join us us_new     on us_new.id = rel.source_id
