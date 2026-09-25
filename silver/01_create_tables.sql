-- =============================================================================
-- DDL Script: Table Creation for ELT Pipeline (Silver Layer)
-- Cleaned, standardized, and validated tables with audit timestamp and relations
-- =============================================================================

-- 1. Silver CRM: Product Info (Parent)
CREATE TABLE IF NOT EXISTS silver_crm_prd_info (
    prd_id         INT,
    cat_id         VARCHAR(50),
    prd_key        VARCHAR(50) PRIMARY KEY,
    prd_nm         VARCHAR(100),
    prd_cost       NUMERIC(12, 2),
    prd_line       VARCHAR(50),
    prd_start_dt   DATE,
    prd_end_dt     DATE,
    dwh_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Silver CRM: Customer Info (Parent)
CREATE TABLE IF NOT EXISTS silver_crm_cust_info (
    cst_id             INT UNIQUE,
    cst_key            VARCHAR(50) PRIMARY KEY,
    cst_firstname      VARCHAR(100),
    cst_lastname       VARCHAR(100),
    cst_marital_status VARCHAR(20),
    cst_gndr           VARCHAR(20),
    cst_create_date    DATE,
    dwh_created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Silver ERP: Customer Demographics (Child -> silver_crm_cust_info)
CREATE TABLE IF NOT EXISTS silver_erp_cust_az12 (
    cid            VARCHAR(50) PRIMARY KEY,
    bdate          DATE,
    gen            VARCHAR(20),
    dwh_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_az12_cust FOREIGN KEY (cid) REFERENCES silver_crm_cust_info(cst_key) ON DELETE CASCADE
);

-- 4. Silver ERP: Customer Locations (Child -> silver_crm_cust_info)
CREATE TABLE IF NOT EXISTS silver_erp_loc_a101 (
    cid            VARCHAR(50) PRIMARY KEY,
    cntry          VARCHAR(100),
    dwh_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_loc_cust FOREIGN KEY (cid) REFERENCES silver_crm_cust_info(cst_key) ON DELETE CASCADE
);

-- 5. Silver CRM: Sales Details (Child -> silver_crm_prd_info & silver_crm_cust_info)
CREATE TABLE IF NOT EXISTS silver_crm_sales_details (
    sls_ord_num    VARCHAR(50),
    sls_prd_key    VARCHAR(50),
    sls_cust_id    INT,
    sls_order_dt   DATE,
    sls_ship_dt    DATE,
    sls_due_dt     DATE,
    sls_sales      NUMERIC(12, 2),
    sls_quantity   INT,
    sls_price      NUMERIC(12, 2),
    dwh_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sales_prd FOREIGN KEY (sls_prd_key) REFERENCES silver_crm_prd_info(prd_key) ON DELETE CASCADE,
    CONSTRAINT fk_sales_cust FOREIGN KEY (sls_cust_id) REFERENCES silver_crm_cust_info(cst_id) ON DELETE CASCADE
);

-- 6. Silver ERP: Product Categories
CREATE TABLE IF NOT EXISTS silver_erp_px_cat_g1v2 (
    id             VARCHAR(50) PRIMARY KEY,
    cat            VARCHAR(100),
    subcat         VARCHAR(100),
    maintenance    VARCHAR(10),
    dwh_created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
