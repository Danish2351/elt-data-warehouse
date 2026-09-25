-- =============================================================================
-- Truncate & Load Script for ELT Pipeline (Bronze Layer)
-- Truncates each table and inserts data from mounted CSV files
-- =============================================================================

-- 1. CRM Sales Details
TRUNCATE TABLE bronze_crm_sales_details;
COPY bronze_crm_sales_details (
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
)
FROM '/datasets/source_crm/sales_details.csv'
WITH (FORMAT csv, HEADER true, NULL '');

-- 2. CRM Product Info
TRUNCATE TABLE bronze_crm_prd_info;
COPY bronze_crm_prd_info (
    prd_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
)
FROM '/datasets/source_crm/prd_info.csv'
WITH (FORMAT csv, HEADER true, NULL '');

-- 3. CRM Customer Info
TRUNCATE TABLE bronze_crm_cust_info;
COPY bronze_crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
)
FROM '/datasets/source_crm/cust_info.csv'
WITH (FORMAT csv, HEADER true, NULL '');

-- 4. ERP Customer Demographics (AZ12)
TRUNCATE TABLE bronze_erp_cust_az12;
COPY bronze_erp_cust_az12 (
    cid,
    bdate,
    gen
)
FROM '/datasets/source_erp/CUST_AZ12.csv'
WITH (FORMAT csv, HEADER true, NULL '');

-- 5. ERP Customer Location (A101)
TRUNCATE TABLE bronze_erp_loc_a101;
COPY bronze_erp_loc_a101 (
    cid,
    cntry
)
FROM '/datasets/source_erp/LOC_A101.csv'
WITH (FORMAT csv, HEADER true, NULL '');

-- 6. ERP Product Category (G1V2)
TRUNCATE TABLE bronze_erp_px_cat_g1v2;
COPY bronze_erp_px_cat_g1v2 (
    id,
    cat,
    subcat,
    maintenance
)
FROM '/datasets/source_erp/PX_CAT_G1V2.csv'
WITH (FORMAT csv, HEADER true, NULL '');
