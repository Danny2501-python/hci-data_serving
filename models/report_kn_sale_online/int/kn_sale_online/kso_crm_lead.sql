select 
      ecl.id,
      ecl.type_data_partner AS kh_cu_moi,
      ecl.overseas_vietnamese AS vk,
      ecl.contact_name AS ten_khach,
      ecl.code_customer AS ma_kh,
      ecl.phone AS sdt,
      date(ecl.arrival_date + '07:00:00'::interval) AS ngay_den_cua,
      ecl.type_crm_id AS loai_ban_ghi,
      date(ecl.create_date + '07:00:00'::interval) AS ngay_tao,
      date(ecl.arrival_date + '07:00:00'::interval) AS ngay_dc,
      date(ecl.booking_date + '07:00:00'::interval) AS ngay_hl,
      ecl.name AS ma_booking,
      ecl.create_by_department AS phong_ban_nguoi_tao,
      ecl.source_id AS nguon_bk_id,
      ecl.ticket_id,
      ecl.active,
      ecl.company_id,
      ecl.stage_id,
      ecl.state_id, 
      ecl.brand_etl,
      ecl.create_uid,
      ecl.reason_cancel_booking
      ----ecl.type_crm_id
  from {{ source('kso_crm_base','crm_lead') }} ecl
  where brand_etl =1
  and active is true
