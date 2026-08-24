{{
  config(materialized = 'table')
}}
-- =============================================================================
-- stg_bsp_crm_base  (Pass 4)
-- CRM tổng quan khách hàng Paris — nguồn cho các stream Lead/BK/HL/DC/TC/DS.
-- Materialized as table: int_bsp_crm_union đọc 6 lần, cần compute 1 lần.
-- =============================================================================
SELECT
    TEXT(stks.ticket_id)              AS ticket_id,
    stks.sdt,
    UPPER(stks.nhan_vien)             AS nv,
    stks.ngay_tao,
    stks.nhom_dv,
    stks.chinhanhphanquyen,
    stks.loai_ban_ghi,
    stks.trang_thai,
    stks.chinhanh,
    stks.nguon_moi                    AS nguon,
    stks.ngay_hl,
    stks.ngay_dc,
    stks.ngay_den_cua,
    stks.vao_so,
    stks.doanh_so,
    stks.ngay_tt,
    stks.ten_khach,
    stks.ma_booking,
    stks.phong_ban_nguoi_tao,
    stks.phong_ban_nguoi_tao1,
    stks.work_email,
    stks.thu_tu,
    stks.line_id,
    stks.tong_tien,
    stks.id crm_id
FROM {{ source('paris', 'view_stag_tongquan_khachhang_sm_pr') }} stks
