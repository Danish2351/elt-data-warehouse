-- =============================================================================
-- DDL Script: Table Creation for ELT Pipeline (Bronze Layer)
-- =============================================================================

-- 1. CRM: Sales Details
CREATE TABLE IF NOT EXISTS bronze_crm_sales_details (
    sls_ord_num    VARCHAR(50),
    sls_prd_key    VARCHAR(50),
    sls_cust_id    INT,
    sls_order_dt   INT,
    sls_ship_dt    INT,
    sls_due_dt     INT,
    sls_sales      NUMERIC(12, 2),
    sls_quantity   INT,
    sls_price      NUMERIC(12, 2)
);

-- 2. CRM: Product Info
CREATE TABLE IF NOT EXISTS bronze_crm_prd_info (
    prd_id         INT,
    prd_key        VARCHAR(50),
    prd_nm         VARCHAR(100),
    prd_cost       NUMERIC(12, 2),
    prd_line       VARCHAR(10),
    prd_start_dt   DATE,
    prd_end_dt     DATE
);

-- 3. CRM: Customer Info
CREATE TABLE IF NOT EXISTS bronze_crm_cust_info (
    cst_id             INT,
    cst_key            VARCHAR(50),
    cst_firstname      VARCHAR(100),
    cst_lastname       VARCHAR(100),
    cst_marital_status VARCHAR(10),
    cst_gndr           VARCHAR(10),
    cst_create_date    DATE
);

-- 4. ERP: Customer Demographics (AZ12)
CREATE TABLE IF NOT EXISTS bronze_erp_cust_az12 (
    cid    VARCHAR(50),
    bdate  DATE,
    gen    VARCHAR(50)
);

-- 5. ERP: Customer Locations (A101)
CREATE TABLE IF NOT EXISTS bronze_erp_loc_a101 (
    cid    VARCHAR(50),
    cntry  VARCHAR(100)
);

-- 6. ERP: Product Category (G1V2)
CREATE TABLE IF NOT EXISTS bronze_erp_px_cat_g1v2 (
    id          VARCHAR(50),
    cat         VARCHAR(100),
    subcat      VARCHAR(100),
    maintenance VARCHAR(10)
);
