CREATE DATABASE telecom_sla;
USE telecom_sla;

#STEP 2 CREATE STAGING TABLES — EVERY COLUMN AS TEXT

CREATE TABLE customers_stage (
    customer_id VARCHAR(20),
    name VARCHAR(100),
    region VARCHAR(50),
    signup_date VARCHAR(30)
);

CREATE TABLE engineers_stage (
    engineer_id VARCHAR(20),
    name VARCHAR(100),
    region VARCHAR(50),
    skill_type VARCHAR(50)
);

CREATE TABLE sla_targets_stage (
    complaint_type VARCHAR(50),
    severity VARCHAR(50),
    target_hours VARCHAR(20)
);

CREATE TABLE complaints_stage (
    complaint_id VARCHAR(20),
    customer_id VARCHAR(20),
    region VARCHAR(50),
    complaint_type VARCHAR(50),
    severity VARCHAR(50),
    fault_location VARCHAR(50),
    created_at VARCHAR(50)
);

CREATE TABLE assignments_stage (
    complaint_id VARCHAR(20),
    engineer_id VARCHAR(20),
    assigned_at VARCHAR(50),
    resolved_at VARCHAR(50)
);

#STEP 4 VERIFY THE IMPORT
SELECT COUNT(*) FROM customers_stage; 
SELECT COUNT(*) FROM engineers_stage; 
SELECT COUNT(*) FROM sla_targets_stage; 
SELECT COUNT(*) FROM complaints_stage; 
SELECT COUNT(*) FROM assignments_stage; 


#STEP 5 ADD SURROGATE KEYS FOR SAFE DE-DUPLICATION
ALTER TABLE complaints_stage ADD COLUMN row_id INT AUTO_INCREMENT PRIMARY KEY;
ALTER TABLE assignments_stage ADD COLUMN row_id INT AUTO_INCREMENT PRIMARY KEY;

#STEP 6 ISSUE 1 — REMOVE DUPLICATE COMPLAINT/ASSIGNMENT RECORDS
-- Identify duplicates
SELECT complaint_id, COUNT(*) FROM complaints_stage
GROUP BY complaint_id HAVING COUNT(*) > 1;

-- Remove extras, keep the first-imported copy of each complaint_id
DELETE c1 FROM complaints_stage c1
INNER JOIN complaints_stage c2
ON c1.complaint_id = c2.complaint_id AND c1.row_id > c2.row_id;

SET SQL_SAFE_UPDATES = 0;



DELETE a1 FROM assignments_stage a1
INNER JOIN assignments_stage a2
ON a1.complaint_id = a2.complaint_id AND a1.row_id > a2.row_id;

#STEP 7 ISSUES 2, 3, 4, 13 — NORMALISE TEXT FIELDS
-- Whitespace (Issue 2 & 13)

UPDATE complaints_stage SET region = TRIM(region);


UPDATE customers_stage SET name = TRIM(name);

UPDATE engineers_stage SET name = TRIM(name);

-- Inconsistent casing in complaint_type (Issue 3)
UPDATE complaints_stage
SET complaint_type = CONCAT(
UPPER(SUBSTRING(TRIM(complaint_type),1,1)),
LOWER(SUBSTRING(TRIM(complaint_type),2))
);

-- City naming inconsistency — Bangalore vs Bengaluru (Issue 4)
UPDATE complaints_stage SET region = 'Bangalore' WHERE region = 'Bengaluru';


#STEP 9 ISSUES 7 & 8 — MISSING FAULT LOCATION & CUSTOMER ID

UPDATE complaints_stage
SET fault_location = 'UNKNOWN'
WHERE complaint_type = 'Network'
AND (fault_location IS NULL OR TRIM(fault_location) = '');

UPDATE complaints_stage
SET customer_id = 'UNKNOWN'
WHERE customer_id IS NULL OR TRIM(customer_id) = '';

#STEP 10  ISSUES 9 & 10 — FIX ASSIGNMENT TIMESTAMP ERRORS

ALTER TABLE assignments_stage ADD COLUMN duration_suspect TINYINT DEFAULT 0;

UPDATE assignments_stage
SET duration_suspect = 1
WHERE resolved_at IS NOT NULL
AND TRIM(resolved_at) != ''
AND TRIM(assigned_at) != ''
AND TIMESTAMPDIFF(
    HOUR,
    STR_TO_DATE(assigned_at, '%Y-%m-%d %H:%i:%s'),
    STR_TO_DATE(resolved_at, '%Y-%m-%d %H:%i:%s')
) > 720;

#STEP 11 — DUPLICATE CUSTOMER MASTER RECORDS

SELECT customer_id, name, region
FROM customers_stage
WHERE customer_id LIKE 'CUSTD%'
ORDER BY name;

-- Optional: find likely matches to investigate manually

SELECT a.customer_id AS original_id, b.customer_id AS likely_duplicate, a.name, a.region
FROM customers_stage a
JOIN customers_stage b
ON LOWER(TRIM(a.name)) = LOWER(TRIM(b.name))
AND a.region = b.region
AND a.customer_id <> b.customer_id
AND b.customer_id LIKE 'CUSTD%';

#STEP 12 — STANDARDISE MIXED DATE FORMATS

ALTER TABLE complaints_stage ADD COLUMN created_at_clean DATETIME;

UPDATE complaints_stage
SET created_at_clean = CASE
WHEN created_at REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
THEN STR_TO_DATE(created_at, '%Y-%m-%d %H:%i:%s')
WHEN created_at REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}'
THEN STR_TO_DATE(created_at, '%d-%m-%Y %H:%i:%s')
ELSE NULL END;

-- Confirm every row parsed successfully

SELECT COUNT(*) FROM complaints_stage WHERE created_at_clean IS NULL;
-- Expected: 0

#STEP 13 - BUILD THE FINAL CLEAN, TYPED RELATIONAL TABLES

CREATE TABLE customers (
customer_id VARCHAR(20) PRIMARY KEY,
name VARCHAR(100),
region VARCHAR(50),
signup_date DATE
);

INSERT INTO customers
SELECT DISTINCT customer_id, name, region, STR_TO_DATE(signup_date, '%Y-%m-%d')
FROM customers_stage;

CREATE TABLE engineers (
engineer_id VARCHAR(20) PRIMARY KEY,
name VARCHAR(100),
region VARCHAR(50),
skill_type VARCHAR(50)
);

INSERT INTO engineers SELECT * FROM engineers_stage;
CREATE TABLE sla_targets (
complaint_type VARCHAR(50),
severity VARCHAR(50),
target_hours INT,
PRIMARY KEY (complaint_type, severity)
);

INSERT INTO sla_targets
SELECT complaint_type, severity, CAST(target_hours AS UNSIGNED) FROM sla_targets_stage;

CREATE TABLE complaints (
complaint_id VARCHAR(20) PRIMARY KEY,
customer_id VARCHAR(20),
region VARCHAR(50),
complaint_type VARCHAR(50),
severity VARCHAR(50),
fault_location VARCHAR(50),
created_at DATETIME,
FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

INSERT INTO assignments
SELECT 
    complaint_id, 
    NULLIF(TRIM(engineer_id), ''),
    STR_TO_DATE(NULLIF(TRIM(assigned_at), ''), '%Y-%m-%d %H:%i:%s'),
    STR_TO_DATE(NULLIF(TRIM(resolved_at), ''), '%Y-%m-%d %H:%i:%s'),
    duration_suspect
FROM assignments_stage;

#STEP 14 - ADD INDEXES FOR JOIN PERFORMANCE

CREATE INDEX idx_complaints_region ON complaints(region);
CREATE INDEX idx_complaints_type ON complaints(complaint_type);
CREATE INDEX idx_complaints_created ON complaints(created_at);
CREATE INDEX idx_assignments_engineer ON assignments(engineer_id);


# STEP 15 RUN THE 12 ANALYSIS QUERIES

--- Query 1 — Overall KPI Summary

SELECT
COUNT(*) AS total_complaints,
ROUND(SUM(CASE WHEN a.resolved_at IS NOT NULL
AND a.resolved_at <= DATE_ADD(a.assigned_at, INTERVAL s.target_hours HOUR)
THEN 1 ELSE 0 END) * 100.0 /
SUM(CASE WHEN a.resolved_at IS NOT NULL THEN 1 ELSE 0 END), 1) AS sla_compliance_pct,
ROUND(AVG(CASE WHEN a.resolved_at IS NOT NULL
THEN TIMESTAMPDIFF(HOUR, a.assigned_at, a.resolved_at) END), 1) AS avg_mttr_hours
FROM complaints c
JOIN assignments a ON c.complaint_id = a.complaint_id
JOIN sla_targets s ON c.complaint_type = s.complaint_type AND c.severity = s.severity
WHERE a.duration_suspect = 0;

--- Query 2 — SLA Breach % by Complaint Type (JOIN)

SELECT c.complaint_type, COUNT(*) AS total,
ROUND(SUM(CASE WHEN a.resolved_at > DATE_ADD(a.assigned_at, INTERVAL s.target_hours HOUR)
THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS breach_pct
FROM complaints c
JOIN assignments a ON c.complaint_id = a.complaint_id
JOIN sla_targets s ON c.complaint_type = s.complaint_type AND c.severity = s.severity
WHERE a.resolved_at IS NOT NULL AND a.duration_suspect = 0
GROUP BY c.complaint_type
ORDER BY breach_pct DESC;

--- Query 3 — SLA Breach % by Region (JOIN)

SELECT c.region, COUNT(*) AS total,
ROUND(SUM(CASE WHEN a.resolved_at > DATE_ADD(a.assigned_at, INTERVAL s.target_hours HOUR)
THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS breach_pct
FROM complaints c
JOIN assignments a ON c.complaint_id = a.complaint_id
JOIN sla_targets s ON c.complaint_type = s.complaint_type AND c.severity = s.severity
WHERE a.resolved_at IS NOT NULL AND a.duration_suspect = 0
GROUP BY c.region
ORDER BY breach_pct DESC;

--- Query 4 — MTTR by Engineer (JOIN)

SELECT e.engineer_id, e.name, e.region, COUNT(*) AS tickets_handled,
ROUND(AVG(TIMESTAMPDIFF(HOUR, a.assigned_at, a.resolved_at)), 1) AS avg_mttr_hours
FROM assignments a 
JOIN engineers e ON a.engineer_id = e.engineer_id
WHERE a.resolved_at IS NOT NULL AND a.duration_suspect = 0
GROUP BY e.engineer_id, e.name, e.region
ORDER BY avg_mttr_hours DESC
LIMIT 20;

--- Query 5 — Engineer Utilisation vs. Regional Average (JOIN + window function)
SELECT region, engineer_id, ticket_count,
ROUND(ticket_count / AVG(ticket_count) OVER (PARTITION BY region), 2) AS utilisation_index
FROM (
SELECT e.region, e.engineer_id, COUNT(a.complaint_id) AS ticket_count
FROM engineers e
LEFT JOIN assignments a ON a.engineer_id = e.engineer_id
GROUP BY e.region, e.engineer_id
) t
ORDER BY utilisation_index DESC;

--- Query 6 — Recurring Fault Hotspots (JOIN, dataset-wide approximation)

SELECT c.fault_location, c.complaint_type, COUNT(*) AS complaint_count,
ROUND(AVG(CASE WHEN a.resolved_at > DATE_ADD(a.assigned_at, INTERVAL s.target_hours HOUR)
THEN 1 ELSE 0 END) * 100, 1) AS breach_pct
FROM complaints c
JOIN assignments a ON c.complaint_id = a.complaint_id
JOIN sla_targets s ON c.complaint_type = s.complaint_type AND c.severity = s.severity
WHERE c.fault_location != 'UNKNOWN' AND a.resolved_at IS NOT NULL
GROUP BY c.fault_location, c.complaint_type
HAVING COUNT(*) >= 15
ORDER BY complaint_count DESC;

--- Query 7 — Repeat Complaints, 90-Day Lookback (self-JOIN)

SELECT DISTINCT c1.complaint_id, c1.customer_id, c1.complaint_type, c1.created_at
FROM complaints c1
JOIN complaints c2
ON c1.customer_id = c2.customer_id
AND c1.complaint_type = c2.complaint_type
AND c1.complaint_id <> c2.complaint_id
AND c2.created_at BETWEEN DATE_SUB(c1.created_at, INTERVAL 90 DAY) AND c1.created_at
WHERE c1.customer_id != 'UNKNOWN';

--- Query 8 — Skill-Mismatch Rate (JOIN, AS-IS process flaw)

SELECT
ROUND(SUM(CASE WHEN e.skill_type <> c.complaint_type THEN 1 ELSE 0 END) * 100.0
/ COUNT(*), 1) AS mismatch_pct
FROM complaints c
JOIN assignments a ON c.complaint_id = a.complaint_id
JOIN engineers e ON a.engineer_id = e.engineer_id;

--- Query 9 — Monthly Complaint Trend
SELECT DATE_FORMAT(created_at, '%Y-%m') AS month, complaint_type, COUNT(*) AS total
FROM complaints
GROUP BY month, complaint_type
ORDER BY month;

--- Query 10 — Severity Distribution & Breach Rate (JOIN)

SELECT c.severity, COUNT(*) AS total,
ROUND(SUM(CASE WHEN a.resolved_at > DATE_ADD(a.assigned_at, INTERVAL s.target_hours HOUR)
THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS breach_pct
FROM complaints c
JOIN assignments a ON c.complaint_id = a.complaint_id
JOIN sla_targets s ON c.complaint_type = s.complaint_type AND c.severity = s.severity
WHERE a.resolved_at IS NOT NULL
GROUP BY c.severity;

--- Query 11 — Top 20 Customers by Complaint Count

SELECT customer_id, COUNT(*) AS complaint_count
FROM complaints
WHERE customer_id != 'UNKNOWN'
GROUP BY customer_id
ORDER BY complaint_count DESC
LIMIT 20;

# STEP 16 CREATE VIEWS FOR POWER BI

CREATE VIEW vw_kpi_summary AS
SELECT c.complaint_type, c.region, c.severity, c.created_at,
a.assigned_at, a.resolved_at, s.target_hours
FROM complaints c
JOIN assignments a ON c.complaint_id = a.complaint_id
JOIN sla_targets s ON c.complaint_type = s.complaint_type AND c.severity = s.severity
WHERE a.duration_suspect = 0;

CREATE VIEW vw_engineer_utilisation AS
SELECT e.engineer_id, e.region, e.skill_type, COUNT(a.complaint_id) AS ticket_count
FROM engineers e
LEFT JOIN assignments a ON a.engineer_id = e.engineer_id
GROUP BY e.engineer_id, e.region, e.skill_type;

CREATE VIEW vw_monthly_trend AS
SELECT DATE_FORMAT(created_at, '%Y-%m') AS month, complaint_type, region, COUNT(*) AS total
FROM complaints
GROUP BY month, complaint_type, region;

SHOW FULL TABLES WHERE Table_type = 'VIEW';

CREATE OR REPLACE VIEW vw_engineer_utilisation AS
SELECT e.engineer_id, e.region, e.skill_type, 
       COUNT(a.complaint_id) AS ticket_count,
       COUNT(a.complaint_id) / AVG(COUNT(a.complaint_id)) OVER (PARTITION BY e.region) AS utilisation_index
FROM engineers e
LEFT JOIN assignments a ON a.engineer_id = e.engineer_id
GROUP BY e.engineer_id, e.region, e.skill_type;



CREATE VIEW vw_root_cause_hotspots AS
SELECT c.fault_location, c.complaint_type, COUNT(*) AS complaint_count,
ROUND(AVG(CASE WHEN a.resolved_at > DATE_ADD(a.assigned_at, INTERVAL s.target_hours HOUR)
THEN 1 ELSE 0 END) * 100, 1) AS breach_pct
FROM complaints c
JOIN assignments a ON c.complaint_id = a.complaint_id
JOIN sla_targets s ON c.complaint_type = s.complaint_type AND c.severity = s.severity
WHERE c.fault_location != 'UNKNOWN' AND a.resolved_at IS NOT NULL
GROUP BY c.fault_location, c.complaint_type
HAVING COUNT(*) >= 15
ORDER BY complaint_count DESC;

SELECT * FROM vw_root_cause_hotspots LIMIT 10;

CREATE OR REPLACE VIEW vw_root_cause_hotspots AS
SELECT c.fault_location, c.complaint_type, COUNT(*) AS complaint_count,
ROUND(AVG(CASE WHEN a.resolved_at > DATE_ADD(a.assigned_at, INTERVAL s.target_hours HOUR)
THEN 1 ELSE 0 END) * 100, 1) AS breach_pct
FROM complaints c
JOIN assignments a ON c.complaint_id = a.complaint_id
JOIN sla_targets s ON c.complaint_type = s.complaint_type AND c.severity = s.severity
WHERE c.fault_location != 'UNKNOWN' 
  AND c.fault_location IS NOT NULL 
  AND TRIM(c.fault_location) != ''
  AND a.resolved_at IS NOT NULL
GROUP BY c.fault_location, c.complaint_type
HAVING COUNT(*) >= 15
ORDER BY complaint_count DESC;

SELECT * FROM vw_root_cause_hotspots LIMIT 10;



















