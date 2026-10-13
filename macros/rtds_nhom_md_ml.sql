{#
    Phân nhóm nguồn MD / ML cho báo cáo tập đoàn HCI (report_tableau_doanh_so_tap_doan_HCI) — port từ
    field `class_source_inidcate` của Tableau workbook "KANGNAM - BỘ CHỈ SỐ KINH DOANH - 2025.twbx"
    (user chốt 2026-09-26: Kangnam/Paris + nguồn ERP của Hồng Hà dùng đúng quy tắc workbook này).

    Workbook xếp nguồn theo THỨ TỰ ƯU TIÊN (điều kiện trước khớp thì dừng):
        1. source_mgm        ❶.2 KH giới thiệu (MGM)   source_id IN (85,86,125,137,138,210,295,296,532,566)
        2. source_loyalty    ❶.1 KH cũ (Return)         source_id IN (91,94,95,96,123,127,209,283,290,291,
                                                        531,565,695) OR tên nguồn chứa 'quay lại'
        3. source_mkt_branch ❶.3 MKT Cơ sở              source_id IN (69,208,277,530,545,546)
        4. source_ctv        ❶.5 CTV                     source_id IN (74,130,211,264,298,533,567)
        5. source_affiliate  ❶.4 Đối tác (Affiliate)     source_id IN (68,78,49,93,...,661) OR
                                                        category_source_id IN (117,118)
        6. source_md         ❷ Nguồn Marketing (MD)      category_source_id IN (105,119)
        7. source_other      ❶.6 Khác
    MD = nhóm 6; ML = toàn bộ khối ❶ (nhóm 1-5 + 7 "Khác") — user chốt "Khác" tính vào ML.

    Dùng: {{ rtds_nhom_md_ml('cl.source_id', 'ss.category_id', 'ss.source') }} → 'MD' | 'ML'
    (category_source_id của workbook = stag_sources.category_id, join ss.old_id = source_id).
#}
{% macro rtds_nhom_md_ml(source_id, category_source_id, source_name) %}
    case
        when coalesce({{ source_id }}, 0) in (85, 86, 125, 137, 138, 210, 295, 296, 532, 566) then 'ML'
        when coalesce({{ source_id }}, 0) in (91, 94, 95, 96, 123, 127, 209, 283, 290, 291, 531, 565, 695)
          or coalesce(lower({{ source_name }}) like '%quay lại%', false) then 'ML'
        when coalesce({{ source_id }}, 0) in (69, 208, 277, 530, 545, 546) then 'ML'
        when coalesce({{ source_id }}, 0) in (74, 130, 211, 264, 298, 533, 567) then 'ML'
        when coalesce({{ source_id }}, 0) in (68, 78, 49, 93, 129, 131, 168, 204, 205, 206, 207, 223, 263, 276,
                                              284, 285, 286, 294, 528, 529, 562, 563, 564,
                                              670, 671, 673, 672, 674, 675,
                                              650, 652, 651, 653, 655, 654, 656, 657, 659, 660, 661)
          or coalesce({{ category_source_id }}, 0) in (117, 118) then 'ML'
        when coalesce({{ category_source_id }}, 0) in (105, 119) then 'MD'
        -- (2026-10-13, user chốt) nguồn "DG - MD - …" (Dr Giang/THV, category 113) tính MD
        when coalesce({{ source_name }} ilike 'DG - MD -%', false) then 'MD'
        else 'ML'
    end
{% endmacro %}

{#
    Biến thể cho KHÁCH HÀNG (đến cửa / thành công) — workbook "Bộ chỉ số kinh doanh" đếm khách MD
    ("❷.4 Số Khách đến cửa (MD)" / "❷.5 Số Khách thành công (MD)") bằng cờ `is_source_md` TRỰC TIẾP,
    KHÔNG qua thứ tự ưu tiên class_source_inidcate của doanh số:
        is_source_md = category_source_id IN (105,119)
                       AND NOT is_source_loyalty (Return)  AND NOT is_source_mkt_branch (MKT Cơ sở)
    → nguồn MGM/CTV/Affiliate có category 105/119 vẫn là MD với khách hàng (nhưng là ML với doanh số).
    Còn lại → ML (MD + ML = tổng khách).
    Dùng: {{ rtds_nhom_md_ml_khach('source_id', 'category_source_id', 'source') }} → 'MD' | 'ML'
#}
{% macro rtds_nhom_md_ml_khach(source_id, category_source_id, source_name) %}
    case
        -- (2026-10-13, user chốt) nguồn "DG - MD - …" (Dr Giang/THV, category 113 — không có trong workbook Kangnam) tính MD
        when coalesce({{ source_name }} ilike 'DG - MD -%', false) then 'MD'
        when coalesce({{ category_source_id }}, 0) in (105, 119)
         and not (
                coalesce({{ source_id }}, 0) in (91, 94, 95, 96, 123, 127, 209, 283, 290, 291, 531, 565, 695)
             or coalesce(lower({{ source_name }}) like '%quay lại%', false)
         )
         and coalesce({{ source_id }}, 0) not in (69, 208, 277, 530, 545, 546)
            then 'MD'
        else 'ML'
    end
{% endmacro %}
