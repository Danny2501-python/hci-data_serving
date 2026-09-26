# Logic: report_thv_revenue

Doanh số **Tiêu Hóa Việt** (THV, brand_etl = 8) từ HIS/EHC riêng của THV
(`ehc_tb_*_thv`), gắn nhóm nguồn báo cáo (MD/ML...), đối chiếu nguồn ERP, và
dựng bảng báo cáo doanh số vs target theo mẫu người dùng.
Tag dbt: `report_thv_revenue` (`int`/`stag` = ephemeral, `mart` = table).

Output vật lý:
- **`report_thv_revenue`** — bảng chi tiết từng phiếu (dịch vụ + nhà thuốc).
- **`report_thv_revenue_target`** — bảng báo cáo tổng hợp theo tháng (dòng
  1 → 3 như mẫu), có target, % hoàn thành, tỷ lệ đóng góp.

---

## Kiến trúc

```
Sources (rtr_base, schema public)                     Seed
  ehc_tb_nguoigioithieu_thv + ehc_tb_dm_hoahong..._thv   rtr_target
     └── int/rtr_nhom_nguoigioithieu  (dimension NGT + nhóm báo cáo)
            ├── int/rtr_ehc_payment_service   ← ehc_tb_invoice_thv
            └── int/rtr_ehc_payment_medicine  ← ehc_tb_invoicemedicine_thv
  crm_lead (brand 8) + m_utm_source_old_new_map
     └── int/rtr_lead
                    └── stag/rtr_combine  (union DV + NT, join ERP, chốt nhóm)
                           ├── mart/report_thv_revenue
                           └── mart/report_thv_revenue_target ← int/rtr_target_latest ← seed rtr_target
```

---

## Tầng INT

### `rtr_nhom_nguoigioithieu` — dimension người giới thiệu
Mỗi người giới thiệu (`ehc_tb_nguoigioithieu_thv`) + nhóm hoa hồng native, và 2 cột suy ra:

**`nhom_nguon_baocao`** — rule theo `nguoigioithieuname`, **thứ tự ưu tiên cố định**:

| # | Điều kiện | Nhóm |
|---|---|---|
| 0 | `nguoigioithieuid` = 85 / 45 / 39 (ngoại lệ chỉ định) | MD / CBNV / MO |
| 1 | tên chứa `38` | PK38 |
| 2 | chứa `CBNV` và không chứa `CTV` | CBNV |
| 3 | `Khách hàng cũ quay lại (loyalty)` / `ML- Campaign Loyalty` | Loyalty |
| 4 | `MD - Phát triển cộng đồng` | MD_Seeding |
| 5 | chứa `Vãng lai` | VL |
| 6 | chứa `MD` | MD |
| 7 | chứa `CTV` hoặc `Khách hàng giới thiệu khách hàng`, trừ `CTV-MD`/`CTV-ML` | ĐTKD - MGM |
| 8 | fallback: không phải `CTV-MD`/`CTV-ML`, nhóm native không chứa `MD`/`ML` | ĐTKD - MGM |
| – | không khớp | NULL |

**`nhom_md_ml_baocao`** (suy từ nhóm trên, chưa xét ngày): CBNV→CBNV · MO→MO ·
{MD, MD_Seeding, VL}→MD · {PK38, ĐTKD - MGM, Loyalty}→ML.

### `rtr_ehc_payment_service` — doanh thu dịch vụ
`ehc_tb_invoice_thv` (`huyphieu_status = 0`) + patientrecord + người giới thiệu +
`rtr_nhom_nguoigioithieu`. Loại phiếu 2 (Hoàn tiền) / 4 (Hoàn ứng) đảo dấu âm.
Cột nhóm mang hậu tố `_ehc` (nhom_nguon_baocao_ehc, nhom_md_ml_baocao_ehc).
THV **không có nhánh cọc** (`invoicerequest`) như Hồng Hà.

### `rtr_ehc_payment_medicine` — doanh thu nhà thuốc
`ehc_tb_invoicemedicine_thv` (`huyphieu_status = 0`), join medicinebill theo
`medicinebillid` (1-1); `patientname` = `khachlename` (tên khách mua thuốc).
Không đảo dấu (chỉ có loại phiếu 1).

**Fallback người giới thiệu** khi phiếu không có `patientrecordid` hợp lệ
(hồ sơ không ra `nguoigioithieuid`), chỉ nhận khi **duy nhất 1 ứng viên**:
1. Khớp tên + SĐT (`khachlename`/`khachle_phone` = `patientname`/`patientphone`).
2. Khớp tên thuần, chỉ khi mọi hồ sơ trùng tên cùng 1 người giới thiệu.

Mơ hồ → để NULL, không đoán. Bộ cột được đặt **cùng tên, cùng thứ tự (17 cột)**
với `rtr_ehc_payment_service` để union trực tiếp.

### `rtr_lead` — booking ERP
`crm_lead` brand 8, `active = true`, ngày cộng 7h (UTC → VN).
`old_source_name` / `new_source_name` qua `m_utm_source_old_new_map` (brand 8);
map mới được `distinct (new_source_id, new_source_name)` trước khi join để tránh fan-out.

### `rtr_target_latest` — target hiện hành
Từ seed `seeds/rtr_target.csv`: lấy dòng `active = true`, nếu trùng
`(ngay_dau_thang, chi_tieu)` thì giữ `ngay_cap_nhat` mới nhất.
Đổi target = **thêm dòng mới active=true + tắt dòng cũ**, không xoá (giữ lịch sử),
rồi `dbt seed --select rtr_target`.
Loại chỉ tiêu: `ds, md, md_khong_thuoc, ml, dtkd, mgm, loyalty` — **chồng nhau, không cộng dồn**.
Seed hiện có T7 → T12/2026.

### `rtr_nguoigioithieu` — (không dùng)
Bảng mapping tay 70 người giới thiệu → nhóm báo cáo (bản cũ). Hiện **không model
nào ref** — đã thay bằng rule tên ở `rtr_nhom_nguoigioithieu`. Giữ để tham khảo/đối chiếu.

---

## Tầng STAG — `rtr_combine`

1. `union all` dịch vụ (`nguon_doanh_thu = 'dich_vu'`) + nhà thuốc (`'nha_thuoc'`).
2. Left join `rtr_lead` theo `id_booking = lead_booking` (mã `BOOK-...` unique, không fan-out)
   → `erp_old_source_id/name`, `erp_new_source_id/name`.
3. Cột so sánh trực quan (chỉ tham khảo, **không** dùng để chốt nhóm):
   - `nguon_ehc` = nhóm hoa hồng native; `nguon_erp` = `erp_new_source_name`.
   - `nguon_sau_mapping`: nhà thuốc → `source_ehc`; dịch vụ → nếu tên nguồn cũ ERP
     và nhóm native EHC chứa nhau thì lấy nhóm EHC, không thì lấy nguồn mới ERP,
     không có ERP thì `source_ehc`.
4. **Chốt nhóm (hiện hành)**: dùng thẳng tầng EHC cho cả dịch vụ và nhà thuốc —
   `nhom_nguon_baocao = nhom_nguon_baocao_ehc`. Không có nguồn → NULL, không mặc định.
   CTE `erp_map` (18 nguồn ERP → nhóm) vẫn còn trong code nhưng **đang tắt**
   (không được dùng); muốn bật lại override ERP cho dịch vụ thì xem lịch sử git.
5. **`nhom_md_ml_baocao` theo thời gian**: từ `invoicedate >= 2026-09-01`, nhóm
   `VL` (Vãng lai) xếp sang **ML**; trước đó VL → MD.
6. Cột đặt tên rõ nghĩa: `nguoigioithieu` (= `source_ehc`, tên cá nhân),
   `nhom_nguoigioithieu` (= nhóm hoa hồng native).

---

## Tầng MART

### `report_thv_revenue`
`select * from rtr_combine` — bảng chi tiết, 1 dòng / phiếu. Không cần dedup (các
join đều 1-1). Là nguồn THV của `report_hh_thv_ds_kh`.

### `report_thv_revenue_target` — báo cáo theo mẫu
Mọi dòng **loại CBNV** (`nhom_nguon_baocao = 'CBNV'`), trừ dòng 3 chỉ lấy CBNV.

Cấu trúc dòng (tháng ≥ T9/2026):

| STT | Nội dung | Công thức (dịch vụ = DV, nhà thuốc = NT) | Target |
|---|---|---|---|
| 1 | Doanh số Nội soi Tiêu hóa Việt | tổng DV + NT | `ds` |
| 1.1 / 1.2 | DS dịch vụ / DS nhà thuốc | | – |
| 2 | Doanh số theo Nguồn | = dòng 1 | `ds` |
| 2.1 | MD gồm nhà thuốc | 2.1.1 + 2.1.2 | `md` |
| 2.1.1 | MD không gồm nhà thuốc | DV nhóm MD + MD_Seeding (**không** gồm VL từ T9) | `md` |
| 2.1.1.1 / .2 | MKT Digital / Seeding | DV nhóm MD / MD_Seeding | – |
| 2.1.2 | Nhà thuốc (MD) | **phần dư** = NT − 2.2.5.1 − 2.2.5.2 − 2.2.5.3 | – |
| 2.2 | Nguồn cơ sở | ĐTKD-MGM + Loyalty + 38PM + Khác + Vãng lai DV + khối NT ML | `ml` |
| 2.2.1 | ĐTKD - MGM | DV nhóm ĐTKD - MGM **+ PK38** (từ T9) | `dtkd + mgm` |
| 2.2.2 | Loyalty | DV nhóm Loyalty | `loyalty` |
| 2.2.3 | Khác | DV nhóm MO | – |
| 2.2.4 | Vãng lai (dịch vụ) | DV nhóm VL | – |
| 2.2.5 | Nhà thuốc (ML) + Thuốc bán lẻ | 2.2.5.1 + .2 + .3 | – |
| 2.2.5.1 | Nhà thuốc (ML) | NT nhóm PK38/ĐTKD-MGM/Loyalty **có** nhóm NGT | – |
| 2.2.5.2 | Vãng lai (nhà thuốc) | NT nhóm VL | – |
| 2.2.5.3 | Thuốc bán lẻ | NT **không** có nhóm NGT | – |
| 3 | Doanh số nguồn đối ngoại, CBNV | DV + NT nhóm CBNV | – |

**Tháng ≤ T8/2026 giữ quy tắc cũ** (để không lệch mẫu đã verify):
- Vãng lai nằm dưới MD (dòng `2.1.1.3`), MD không gồm NT = MD + Seeding + VL.
- `2.2.3` = 38PM (PK38 tách riêng), `2.2.4` = Khác, `2.2.5` = Nhà thuốc (ML)
  (gồm cả NT ML không có nhóm NGT); không có dòng Vãng lai DV/NT riêng, không có Thuốc bán lẻ.
- NT không rõ nguồn rơi vào phần dư "Nhà thuốc (MD)".

Cột output: `ngay_dau_thang, stt, cap` (cấp thụt lề 1-4), `noi_dung, chi_tieu,
doanh_so_thuc_te, pct_hoan_thanh` (tỷ lệ 0-1, không nhân 100),
`ty_le_dong_gop` (so với dòng 1; dòng 3 luôn = 1.0), `ghi_chu`.

Target (`rtr_target_latest`, pivot theo tháng): `ds`, `md`, `ml`, `loyalty`,
`dtkd + mgm`. Chỉ tiêu `md_khong_thuoc` có trong seed nhưng **chưa dùng** (dòng
2.1.1 đang dùng target `md`).

> ⚠️ **Chỉ tháng có target mới xuất hiện trong báo cáo.** Dòng 1 (và `grand_total`)
> inner join với target → tháng không có dòng trong `rtr_target` (hiện: trước
> T7/2026) bị mất toàn bộ khỏi `report_thv_revenue_target`. Muốn xem tháng cũ thì
> phải bổ sung target vào seed.
