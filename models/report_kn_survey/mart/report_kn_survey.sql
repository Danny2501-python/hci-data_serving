-- report_kn_survey: bảng mart khảo sát Kangnam
-- kn_survey_cms_invite (id) LEFT JOIN kn_survey_cms_invite_line (invite_id)
-- -> 1 dòng / câu trả lời; invite chưa có câu trả lời (chưa submit, skipped...) vẫn giữ 1 dòng, cột câu trả lời null
SELECT
    i.*,
    l.invite_line_id,
    l.thu_tu,
    l.cau_hoi,
    l.cau_tra_loi,
    l.cau_tra_loi_khac
FROM {{ ref('int_rks_invite') }} i
    left join {{ ref('int_rks_invite_line') }} l on l.invite_id = i.invite_id and l.brand_etl = i.brand_etl
