-- int_rks_invite_line: câu trả lời khảo sát (kn_survey_cms_invite_line), 1 dòng / câu hỏi của invite
-- answer giữ nguyên dữ liệu gốc (câu nhiều lựa chọn có thể chứa nhiều đáp án cách nhau bằng xuống dòng)
SELECT
    l.id                                                as invite_line_id,
    l.invite_id,
    l.brand_etl,
    l.sequence                                          as thu_tu,
    l.question                                          as cau_hoi,
    l.answer                                            as cau_tra_loi,
    l.other_answer                                      as cau_tra_loi_khac
FROM {{ source('kn_survey', 'kn_survey_cms_invite_line') }} l
