# Logic: report_hh_thv_ds_kh

Gộp **doanh số + mục tiêu** của 2 thương hiệu **Hồng Hà** (brand_etl = 4) và
**Tiêu Hóa Việt** (brand_etl = 8) vào 1 bảng chi tiết chung, cùng bộ cột, để
dựng báo cáo doanh số vs kế hoạch trên 1 nguồn duy nhất.
Tag dbt: `report_hh_thv_ds_kh` (`int`/`stag` = ephemeral, `mart` = table).

Model này **không tự tính doanh số** — chỉ chuẩn hoá cột từ 2 model đã có:
- `rhh_ehc_payment_service` (folder `report_hh_revenue`)
- `report_thv_revenue` + `rtr_target_latest` (folder `report_thv_revenue`)

→ Logic doanh số/nhóm nguồn xem `report_hh_revenue/LOGIC.md` và
`report_thv_revenue/LOGIC.md`.

---

## Kiến trúc

```
report_hh_revenue/mart/rhh_ehc_payment_service ─→ int/rhtdk_hh ──────────┐
report_thv_revenue/mart/report_thv_revenue ─────→ int/rhtdk_thv_ds ──────┼─→ stag/rhtdk_combine ─→ mart/report_hh_thv_ds_kh
report_thv_revenue/int/rtr_target_latest ───────→ int/rhtdk_thv_target ──┘
```

Thứ tự build: phụ thuộc bảng mart của 2 folder kia → khi chạy theo tag phải
build `report_hh_revenue` và `report_thv_revenue` **trước** (hoặc dùng
`dbt build --select +report_hh_thv_ds_kh`).

---

## Tầng INT

| Model | Brand | `nguon_du_lieu` | `loai_chi_tieu` | Nguồn |
|---|---|---|---|---|
| `rhtdk_hh` | 4 Hồng Hà | `Dịch vụ` / `Nhà thuốc` / `Target` (giữ nguyên từ nguồn) | `'ds'` cho dòng Target, NULL cho doanh số | `rhh_ehc_payment_service` (target lấy từ `ggs_target_company` brand_id = 4) |
| `rhtdk_thv_ds` | 8 THV | `dich_vu` → `Dịch vụ`, `nha_thuoc` → `Nhà thuốc` | NULL | `report_thv_revenue` |
| `rhtdk_thv_target` | 8 THV | `Target` | `chi_tieu` của seed (`ds, md, md_khong_thuoc, ml, dtkd, mgm, loyalty`) | `rtr_target_latest` (`invoicedate` = `ngay_dau_thang`) |

Cả 3 model xuất **cùng 27 cột, cùng thứ tự, ép kiểu tường minh** (`::text`,
`::integer`...) để `union all` không lỗi kiểu.

---

## Tầng STAG / MART

- `rhtdk_combine`: `union all` 3 model int.
- `report_hh_thv_ds_kh`: `select * from rhtdk_combine`.

### Bộ cột

| Nhóm cột | Cột | HH | THV |
|---|---|---|---|
| Định danh | `brand_etl`, `ten_thuong_hieu`, `nguon_du_lieu`, `loai_chi_tieu` | ✓ | ✓ |
| Phiếu | `invoicedate`, `sotienphieu`, `loaiphieu`, `sophieu`, `invoiceremark`, `id_booking`, `patientrecordid`, `patientname`, `patientphone` | ✓ | ✓ |
| Chỉ HH | `pl` (DT/cọc), `patientcode`, `invoiceid`, `roomname`, `roomname_kb` | ✓ | NULL |
| Nguồn EHC | `source_ehc` (tên người giới thiệu), `dm_hoahongnguoigioithieu_nguoigioithieuname` (nhóm) | ✓ | ✓ |
| Nguồn ERP | `erp_source_id_old`, `old_source_name`, `erp_source_id_new`, `new_source_name` | ✓ (`new_source_name` hiện NULL) | ✓ (từ `erp_old_*/erp_new_*`) |
| Nhóm báo cáo | `nhom_nguon_baocao`, `nhom_md_ml_baocao`, `nguon_sau_mapping` | NULL (HH chưa có bảng nhóm nguồn báo cáo) | ✓ |

`sotienphieu` ở cả 2 brand đã đảo dấu sẵn cho Hoàn tiền/Hoàn ứng → cộng thẳng.

---

## Cách dùng đúng

1. **Doanh số thực tế**: `nguon_du_lieu in ('Dịch vụ', 'Nhà thuốc')`.
2. **Mục tiêu tổng thương hiệu**: `nguon_du_lieu = 'Target' and loai_chi_tieu = 'ds'`.
   THV có nhiều loại chỉ tiêu mỗi tháng **chồng nhau** (ds ⊇ md, ml...) — cộng hết
   `Target` sẽ ra số sai gấp nhiều lần. Target HH (từ `ggs_target_company`) chỉ có 1 loại, cũng gán `'ds'`.
3. Target nằm ở ngày đầu tháng (`invoicedate`) → so sánh theo tháng
   (`date_trunc('month', invoicedate)`), không theo ngày.
4. **CBNV**: bảng này **không loại CBNV** (khác `report_thv_revenue_target` loại
   CBNV khỏi mọi dòng). Muốn khớp số báo cáo THV thì lọc
   `coalesce(nhom_nguon_baocao, '') <> 'CBNV'` cho brand 8. HH chưa có cột nhóm
   tương đương — nếu cần phải lọc qua `source_ehc`/nhóm hoa hồng.
5. Doanh số HH gồm cả **cọc** (`pl = 'Cọc trong tháng'`) — không trùng với doanh
   thu vì nhánh doanh thu đã loại các `invoiceid` có trong phiếu cọc.
