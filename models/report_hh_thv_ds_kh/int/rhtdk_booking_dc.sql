-- Booking đến cửa (DC) theo ngày khách đến (arrival_date).
-- crm_lead type_crm_id = 2, brand_etl 4 (Hồng Hà) / 8 (Tiêu hóa Việt),
-- ngày tính theo arrival_time (+7h giờ VN). Base: rhtdk_lead_base.
--
-- dc_tc_noi_soi (CHỈ Tiêu hóa Việt): booking đến cửa THÀNH CÔNG (amount_paid
-- > 0) có dùng dịch vụ NỘI SOI — dịch vụ EHC THV (ehc_tb_servicedata_thv) tên
-- chứa "nội soi" hoặc "gói tầm soát", soluong > 0, bỏ nhóm thuốc / vật tư (để
-- không tính "Giấy in bóng nội soi"); không xét trạng thái dịch vụ (bắt cả
-- dòng gói/combo). Danh sách booking nội soi: model rhtdk_noi_soi_thv. THV
-- không thỏa -> false; Hồng Hà -> NULL (không áp dụng). Logic theo truy vấn
-- "khách nội soi thành công" người dùng cung cấp 2026-10-14.

select
    brand_etl,
    ten_thuong_hieu,
    date(arrival_time)                                    as ngay,
    arrival_time,
    ma_lead                                     as booking,
    contact_name,
    phone,
    code_customer,
    erp_source_id_old                           as source_id,
    old_source_name                             as source_name,
    erp_source_id_new                           as new_source_id,
    new_source_name,
    -- Vãng lai: MD trước T10/2026, ML từ T10/2026 (giống THV/rhtdk_hh)
    case
        when nhom_md_ml_raw = 'VL' then
            case when arrival_time >= date '2026-10-01' then 'ML' else 'MD' end
        else nhom_md_ml_raw
    end                                         as nhom_md_ml_baocao,
    -- Số tiền khách đã trả trên booking (crm_lead.amount_paid) — dùng xác định
    -- khách thành công (> 0). Có thể âm (hoàn tiền), giữ nguyên.
    amount_paid,
    case
        when brand_etl = 8 then (amount_paid > 0 and ns.id_booking is not null)
    end                                         as dc_tc_noi_soi
from {{ ref('rhtdk_lead_base') }}
left join {{ ref('rhtdk_noi_soi_thv') }} ns
    on ns.id_booking = ma_lead
where type_crm_id = 2
  and arrival_time is not null
  -- Chỉ lấy nguồn MD (yêu cầu người dùng); Vãng lai tính MD trước T10/2026.
  and (
      nhom_md_ml_raw = 'MD'
      or (nhom_md_ml_raw = 'VL' and arrival_time < date '2026-10-01')
  )
