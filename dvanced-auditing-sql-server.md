# 🔍 Advanced Auditing in SQL Server: Track Data Changes with User and Session Info
**By Dr. Temesgen Deressa**

---

## 🎯 Introduction

In enterprise data systems, tracking *what* changed in your database is essential — but knowing **who** made those changes and **when** they occurred is even more critical. This is especially important for:

- ✅ Regulatory compliance (e.g., GDPR, SOX)
- ✅ Internal audit trails
- ✅ Debugging complex data issues
- ✅ Protecting against unauthorized changes

This guide shows how to implement **advanced SQL Server auditing using triggers** that log:

- The action taken (INSERT, UPDATE, DELETE)
- Before-and-after values
- The user responsible
- Session ID, host, and transaction ID
- Timestamps

---

## 🧠 What You'll Learn

You’ll build a lightweight but powerful auditing system that logs:

- ✅ Type of action (Insert, Update, Delete)  
- ✅ Before-and-after snapshots of key columns  
- ✅ Username (SQL or domain user)  
- ✅ Session ID and client machine  
- ✅ SQL Server transaction context  
- ✅ Timestamps for each operation  

---

## 🧰 Full SQL Code (All-in-One Script)

```sql
-- ========================================
-- STEP 1: CLEANUP – DROP TABLES & TRIGGERS
-- ========================================
IF OBJECT_ID('trg_insert_record', 'TR') IS NOT NULL DROP TRIGGER trg_insert_record;
GO
IF OBJECT_ID('trg_update_record', 'TR') IS NOT NULL DROP TRIGGER trg_update_record;
GO
IF OBJECT_ID('trg_delete_record', 'TR') IS NOT NULL DROP TRIGGER trg_delete_record;
GO
IF OBJECT_ID('record_audit', 'U') IS NOT NULL DROP TABLE record_audit;
GO
IF OBJECT_ID('records', 'U') IS NOT NULL DROP TABLE records;
GO

-- ========================================
-- STEP 2: CREATE MAIN DATA TABLE
-- ========================================
CREATE TABLE records (
    record_id INT IDENTITY(1,1) PRIMARY KEY,
    record_name NVARCHAR(100),
    record_type NVARCHAR(50),
    value DECIMAL(10,2),
    created_at DATETIME DEFAULT GETDATE()
);
GO

-- ========================================
-- STEP 3: CREATE AUDIT TABLE WITH USER/SESSION INFO
-- ========================================
CREATE TABLE record_audit (
    audit_id INT IDENTITY(1,1) PRIMARY KEY,
    record_id INT,
    action_type NVARCHAR(10),
    old_name NVARCHAR(100),
    new_name NVARCHAR(100),
    old_type NVARCHAR(50),
    new_type NVARCHAR(50),
    old_value DECIMAL(10,2),
    new_value DECIMAL(10,2),
    changed_by NVARCHAR(100),
    session_id INT,
    client_host NVARCHAR(100),
    transaction_id BIGINT,
    action_timestamp DATETIME DEFAULT GETDATE()
);
GO

-- ========================================
-- STEP 4: INSERT SAMPLE DATA
-- ========================================
INSERT INTO records (record_name, record_type, value)
VALUES
    ('Alicia White', 'Analyst', 72000),
    ('Benjamin Cruz', 'Engineer', 88000),
    ('Clara Mendez', 'HR', 65000);
GO

-- ========================================
-- STEP 5.1: INSERT TRIGGER
-- ========================================
CREATE TRIGGER trg_insert_record
ON records
AFTER INSERT
AS
BEGIN
    INSERT INTO record_audit (
        record_id, action_type, new_name, new_type, new_value,
        changed_by, session_id, client_host, transaction_id
    )
    SELECT
        record_id, 'INSERT', record_name, record_type, value,
        SYSTEM_USER, @@SPID, HOST_NAME(), CURRENT_TRANSACTION_ID()
    FROM inserted;
END;
GO

-- ========================================
-- STEP 5.2: UPDATE TRIGGER
-- ========================================
CREATE TRIGGER trg_update_record
ON records
AFTER UPDATE
AS
BEGIN
    INSERT INTO record_audit (
        record_id, action_type,
        old_name, new_name,
        old_type, new_type,
        old_value, new_value,
        changed_by, session_id, client_host, transaction_id
    )
    SELECT
        i.record_id, 'UPDATE',
        d.record_name, i.record_name,
        d.record_type, i.record_type,
        d.value, i.value,
        SYSTEM_USER, @@SPID, HOST_NAME(), CURRENT_TRANSACTION_ID()
    FROM inserted i
    INNER JOIN deleted d ON i.record_id = d.record_id
    WHERE
        ISNULL(i.record_name, '') <> ISNULL(d.record_name, '')
        OR ISNULL(i.record_type, '') <> ISNULL(d.record_type, '')
        OR ISNULL(i.value, 0) <> ISNULL(d.value, 0);
END;
GO

-- ========================================
-- STEP 5.3: DELETE TRIGGER
-- ========================================
CREATE TRIGGER trg_delete_record
ON records
AFTER DELETE
AS
BEGIN
    INSERT INTO record_audit (
        record_id, action_type,
        old_name, old_type, old_value,
        changed_by, session_id, client_host, transaction_id
    )
    SELECT
        record_id, 'DELETE',
        record_name, record_type, value,
        SYSTEM_USER, @@SPID, HOST_NAME(), CURRENT_TRANSACTION_ID()
    FROM deleted;
END;
GO

-- ========================================
-- STEP 6: TEST TRIGGERS
-- ========================================
UPDATE records
SET record_type = 'Senior Analyst', value = 77000
WHERE record_name = 'Alicia White';
GO

DELETE FROM records
WHERE record_name = 'Clara Mendez';
GO

INSERT INTO records (record_name, record_type, value)
VALUES ('Daniel Bekele', 'Manager', 99000);
GO

-- ========================================
-- STEP 7: REVIEW AUDIT LOG
-- ========================================
SELECT * FROM record_audit ORDER BY audit_id;
GO
