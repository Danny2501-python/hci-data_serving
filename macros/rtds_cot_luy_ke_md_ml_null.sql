{#
    Các cột lũy kế MD/ML (report_rtds_doanh_so_target_thang_tableau) để NULL trên dòng tháng/HCI
    Group — chỉ có giá trị trên dòng 'Lũy kế cùng kỳ'. Thứ tự PHẢI khớp select cuối của model.
#}
{% macro rtds_cot_luy_ke_md_ml_null() %}
    null::numeric as doanh_so_md_luy_ke, null::numeric as doanh_so_ml_luy_ke,
    null::numeric as target_md_luy_ke, null::numeric as target_ml_luy_ke,
    null::bigint as so_khach_den_cua_md_luy_ke, null::bigint as so_khach_den_cua_ml_luy_ke,
    null::bigint as so_khach_thanh_cong_md_luy_ke, null::bigint as so_khach_thanh_cong_ml_luy_ke,
    null::numeric as target_khach_den_cua_md_luy_ke, null::numeric as target_khach_den_cua_ml_luy_ke,
    null::numeric as target_khach_thanh_cong_md_luy_ke, null::numeric as target_khach_thanh_cong_ml_luy_ke,
    null::numeric as chi_phi_ads_luy_ke
{% endmacro %}
