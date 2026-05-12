-- Bảng stag_payment_transfer_test_dbt: Tổng hợp các giao dịch chuyển tiền ra vào chi nhánh, điều chuyển giữa các chi nhánh
SELECT 
    * 
FROM {{ref('int_pts_stag_payment_all')}}