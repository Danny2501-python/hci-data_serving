{#
    Gộp chi nhánh cho báo cáo tập đoàn HCI (report_tableau_doanh_so_tap_doan_HCI) — user chốt 2026-09-29.
    Trả về company_id SAU KHI GỘP theo var `rtds_gop_chi_nhanh` (dbt_project.yml): từ ngày `tu_ngay`, company
    `tu_company_id` của brand `brand_etl` tính vào `den_company_id` (khớp field chinhanhphanquyen của workbook
    "KANGNAM - BỘ CHỈ SỐ KINH DOANH": company 12 BV Thẩm mỹ Kangnam → 4 BV Kangnam Sài Gòn từ 2026-08-01).
    Áp cho MỌI chỉ số: doanh số (ngày thanh toán), khách / booking (report_date), lead (ngày tạo), target (tháng).

    Dùng: {{ rtds_company_id_gop('spt.company_id', 'spt.payment_date', 'spt.brand_etl') }}
    rồi join m_res_company theo id trả về để lấy tên chi nhánh.
#}
{% macro rtds_company_id_gop(company_id, ngay, brand_etl) %}
    {%- set rules = var('rtds_gop_chi_nhanh', []) -%}
    {%- if rules | length == 0 -%}
        {{ company_id }}
    {%- else -%}
        case
        {%- for r in rules %}
            when {{ brand_etl }} = {{ r.brand_etl }} and {{ company_id }} = {{ r.tu_company_id }}
             and {{ ngay }} >= date '{{ r.tu_ngay }}' then {{ r.den_company_id }}
        {%- endfor %}
            else {{ company_id }}
        end
    {%- endif -%}
{% endmacro %}
