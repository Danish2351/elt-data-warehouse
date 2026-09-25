-- =============================================================================
-- Silver Layer: Truncate & Transform Data Load Script
-- Transforms and enriches data from bronze_* tables into silver_* tables
-- =============================================================================

-- Step 1: Truncate existing silver tables in dependency order
TRUNCATE TABLE silver_crm_sales_details CASCADE;
TRUNCATE TABLE silver_erp_cust_az12 CASCADE;
TRUNCATE TABLE silver_erp_loc_a101 CASCADE;
TRUNCATE TABLE silver_crm_cust_info CASCADE;
TRUNCATE TABLE silver_crm_prd_info CASCADE;
TRUNCATE TABLE silver_erp_px_cat_g1v2 CASCADE;

-- Step 2: Load silver_erp_px_cat_g1v2
INSERT INTO silver_erp_px_cat_g1v2 (
    id,
    cat,
    subcat,
    maintenance,
    dwh_created_at
)
SELECT 
    TRIM(id) AS id,
    TRIM(cat) AS cat,
    TRIM(subcat) AS subcat,
    TRIM(maintenance) AS maintenance,
    CURRENT_TIMESTAMP AS dwh_created_at
FROM bronze_erp_px_cat_g1v2;

-- Step 3: Load silver_crm_prd_info (Deduplicated to latest per prd_key)
WITH deduped_products AS (
    SELECT 
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
        REPLACE(SUBSTRING(prd_key, 7), '-', '_') AS prd_key,
        TRIM(prd_nm) AS prd_nm,
        prd_cost,
        CASE 
            WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
            WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
            WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
            WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,
        prd_start_dt,
        prd_end_dt,
        ROW_NUMBER() OVER (
            PARTITION BY REPLACE(SUBSTRING(prd_key, 7), '-', '_')
            ORDER BY prd_start_dt DESC, prd_id DESC
        ) AS rn
    FROM bronze_crm_prd_info
)
INSERT INTO silver_crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt,
    dwh_created_at
)
SELECT 
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt,
    CURRENT_TIMESTAMP AS dwh_created_at
FROM deduped_products
WHERE rn = 1;

-- Step 4: Load silver_crm_cust_info (Deduplicated to latest per cst_id)
WITH deduped_customers AS (
    SELECT 
        cst_id,
        TRIM(cst_key) AS cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE 
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'n/a'
        END AS cst_marital_status,
        CASE 
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            ELSE 'n/a'
        END AS cst_gndr,
        cst_create_date,
        ROW_NUMBER() OVER (
            PARTITION BY cst_id 
            ORDER BY cst_create_date DESC, cst_key DESC
        ) AS rn
    FROM bronze_crm_cust_info
    WHERE cst_id IS NOT NULL
)
INSERT INTO silver_crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date,
    dwh_created_at
)
SELECT 
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date,
    CURRENT_TIMESTAMP AS dwh_created_at
FROM deduped_customers
WHERE rn = 1;

-- Step 5: Load silver_erp_cust_az12
INSERT INTO silver_erp_cust_az12 (
    cid,
    bdate,
    gen,
    dwh_created_at
)
SELECT 
    REGEXP_REPLACE(TRIM(cid), '^NAS', '') AS cid,
    CASE 
        WHEN bdate > CURRENT_DATE THEN NULL 
        ELSE bdate 
    END AS bdate,
    CASE 
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        ELSE NULL 
    END AS gen,
    CURRENT_TIMESTAMP AS dwh_created_at
FROM bronze_erp_cust_az12;

-- Step 6: Load silver_erp_loc_a101
INSERT INTO silver_erp_loc_a101 (
    cid,
    cntry,
    dwh_created_at
)
SELECT 
    REPLACE(TRIM(cid), '-', '') AS cid,
    CASE 
        WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
        WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
        WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
        ELSE TRIM(cntry)
    END AS cntry,
    CURRENT_TIMESTAMP AS dwh_created_at
FROM bronze_erp_loc_a101;

-- Step 7: Load silver_crm_sales_details
INSERT INTO silver_crm_sales_details (
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price,
    dwh_created_at
)
SELECT 
    TRIM(sls_ord_num) AS sls_ord_num,
    REPLACE(sls_prd_key, '-', '_') AS sls_prd_key,
    sls_cust_id,
    CASE 
        WHEN sls_order_dt IS NULL OR sls_order_dt = 0 OR LENGTH(sls_order_dt::text) < 8 THEN NULL
        ELSE TO_DATE(sls_order_dt::text, 'YYYYMMDD')
    END AS sls_order_dt,
    CASE 
        WHEN sls_ship_dt IS NULL OR sls_ship_dt = 0 OR LENGTH(sls_ship_dt::text) < 8 THEN NULL
        ELSE TO_DATE(sls_ship_dt::text, 'YYYYMMDD')
    END AS sls_ship_dt,
    CASE 
        WHEN sls_due_dt IS NULL OR sls_due_dt = 0 OR LENGTH(sls_due_dt::text) < 8 THEN NULL
        ELSE TO_DATE(sls_due_dt::text, 'YYYYMMDD')
    END AS sls_due_dt,
    CASE 
        WHEN sls_sales IS NULL OR sls_sales <= 0 THEN ROUND(sls_quantity * ABS(COALESCE(sls_price, sls_sales / NULLIF(sls_quantity, 0))), 2)
        ELSE sls_sales
    END AS sls_sales,
    sls_quantity,
    CASE 
        WHEN sls_price IS NULL OR sls_price = 0 THEN ROUND(sls_sales / NULLIF(sls_quantity, 0), 2)
        ELSE ABS(sls_price)
    END AS sls_price,
    CURRENT_TIMESTAMP AS dwh_created_at
FROM bronze_crm_sales_details;
