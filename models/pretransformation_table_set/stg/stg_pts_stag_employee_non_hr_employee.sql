--========================================
-- Truy vấn dữ liệu các user_id nhưng không có thông tin Nhân viên hr_employee
--========================================
-- user_ot = '''
-- SELECT (ROW_NUMBER() OVER (ORDER BY ru.id) + 1) AS id, 
-- 	rp.name AS employee, ru.id user_id, ru.login work_email, ru.partner_id, 
-- 	ru.create_date, ru.write_date, ru.company_id
-- FROM res_users ru 
-- LEFT JOIN hr_employee he ON ru.id = he.user_id 
-- LEFT JOIN res_partner rp ON ru.partner_id = rp.id
-- WHERE COALESCE(he.user_id, 0) = 0  
-- '''
SELECT 
	(ROW_NUMBER() OVER (ORDER BY ru.id) + 1) AS id, 
	rp.name AS employee, ru.id user_id, ru.login work_email, ru.partner_id, 
	ru.create_date, ru.write_date, ru.company_id
FROM {{source('pre_tns','res_users')}} ru 
LEFT JOIN {{source('pre_tns','hr_employee')}} he ON ru.id = he.user_id 
LEFT JOIN {{source('pre_tns','res_partner')}} rp ON ru.partner_id = rp.id
WHERE he.user_id IS NULL  