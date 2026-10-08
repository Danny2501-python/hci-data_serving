-- Booking theo ngày TẠO booking.
-- crm_lead type_crm_id = 2, brand_etl 4 (Hồng Hà) / 8 (Tiêu hóa Việt),
-- ngày tính theo create_time (+7h giờ VN). Base: rhtdk_lead_base.

select
    brand_etl,
    ten_thuong_hieu,
    date(create_time)                                    as ngay,
    create_time,
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
            case when create_time >= date '2026-10-01' then 'ML' else 'MD' end
        else nhom_md_ml_raw
    end                                         as nhom_md_ml_baocao
from {{ ref('rhtdk_lead_base') }}
where type_crm_id = 2
  and create_time is not null
  -- Chỉ lấy nguồn MD (yêu cầu người dùng); Vãng lai tính MD trước T10/2026.
  and (
      nhom_md_ml_raw = 'MD'
      or (nhom_md_ml_raw = 'VL' and create_time < date '2026-10-01')
  )
