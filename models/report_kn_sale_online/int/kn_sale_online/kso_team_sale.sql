-- [2026-10-08] Vat hoa `table_team_sale_trans_field` thanh BANG CO INDEX.
--
-- Ly do (tu EXPLAIN cua ban 383.7s): `table_team_sale_trans_field` la VIEW
-- (relkind = 'v', 799 dong), UNION ALL 2 nhanh + 1 EXISTS. 6 slice goi no trong
-- `join lateral` tuong quan, nen MOI vong lap Postgres phai chay lai toan bo than
-- view = 3 seq scan + 1 HashAggregate -> cost 157.15 / vong lap:
--
--   Seq Scan on cs_agents_api_trans_field          cost 132.55
--   HashAggregate on table_team_sale_group_trans_field  cost  17.00
--   Seq Scan on table_team_sale_trans_field_backup cost   4.77
--
-- Nhan voi so vong lap uoc luong (~2.0M/slice x 6 slice) -> ~1.31 ty tren tong
-- cost 1.426 ty cua ca query. Day la term chiem gan het chi phi.
--
-- View khong index duoc (SQL Error 42809). Vat hoa thanh bang + index
-- (work_email, expiration_date) bien moi vong lap tu 3 seq scan thanh 1 index scan
-- tren 799 dong. Cap voi viec da bo date() o phia cot trong 6 slice (sargable) thi
-- index moi dung duoc cho ca phan range, khop dung `order by expiration_date limit 1`.
--
-- Chi lay 5 cot ma 6 slice thuc su dung. Model nam trong folder report_kn_sale_online/
-- nen tu thua huong tags: ["report_kso"] -> `dbt run --select tag:report_kso` build no
-- truoc mart, khong gap loi "relation does not exist".
--
-- LUU Y: `order by expiration_date limit 1` trong lateral khong co tie-break, nen khi
-- 2 dong cung work_email trung expiration_date thi dong nao thang la KHONG xac dinh.
-- Day la hanh vi co san tu truoc, vat hoa khong lam no nang hon, nhung co the doi
-- dong thang giua cac lan chay. Muon tien dinh thi phai them tie-break -> doi so.
{{
  config(
    materialized = 'table',
    alias = 'int_kso_team_sale',
    indexes = [
      {'columns': ['work_email', 'expiration_date'], 'type': 'btree'}
    ]
  )
}}

select
      work_email,
      name,
      group_name,
      "group",
      expiration_date
from {{ source('kso_crm_base', 'table_team_sale_trans_field') }}
