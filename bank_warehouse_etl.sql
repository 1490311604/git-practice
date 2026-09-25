-- =============================================
-- 文件名：bank_warehouse_etl.sql
-- 功能描述：银行数据仓库ETL处理及数据质量校验
-- 创建日期：2026-09-21
-- 版本：V1.0
-- =============================================

-- =============================================
-- 第一部分：基础数据表定义
-- =============================================

-- 1. 客户信息源表（ODS层）
DROP TABLE IF EXISTS ods_customer_info;
CREATE TABLE ods_customer_info (
    customer_id     VARCHAR(20),      -- 客户号
    customer_name   VARCHAR(100),     -- 客户姓名
    id_type         VARCHAR(10),      -- 证件类型（01-身份证，02-护照，03-军官证）
    id_no           VARCHAR(30),      -- 证件号码
    gender          VARCHAR(2),       -- 性别（M-男，F-女）
    birth_date      DATE,             -- 出生日期
    mobile_phone    VARCHAR(20),      -- 手机号码
    email           VARCHAR(100),     -- 电子邮箱
    create_time     DATETIME,         -- 创建时间
    update_time     DATETIME,         -- 更新时间
    batch_date      VARCHAR(10)       -- 数据批次日期
);

-- 2. 账户信息源表（ODS层）
DROP TABLE IF EXISTS ods_account_info;
CREATE TABLE ods_account_info (
    account_no      VARCHAR(30),      -- 账号
    customer_id     VARCHAR(20),      -- 客户号
    account_type    VARCHAR(10),      -- 账户类型（01-活期，02-定期，03-贷款）
    currency_code   VARCHAR(3),       -- 币种（CNY-人民币，USD-美元）
    open_date       DATE,             -- 开户日期
    close_date      DATE,             -- 销户日期
    balance         DECIMAL(18,2),    -- 账户余额
    status          VARCHAR(2),       -- 账户状态（01-正常，02-冻结，03-销户）
    branch_code     VARCHAR(10),      -- 开户网点代码
    batch_date      VARCHAR(10)       -- 数据批次日期
);

-- 3. 交易流水源表（ODS层）
DROP TABLE IF EXISTS ods_transaction;
CREATE TABLE ods_transaction (
    transaction_id  VARCHAR(30),      -- 交易流水号
    account_no      VARCHAR(30),      -- 账号
    transaction_type VARCHAR(10),     -- 交易类型（01-存款，02-取款，03-转账）
    transaction_amt DECIMAL(18,2),    -- 交易金额
    transaction_date DATE,            -- 交易日期
    transaction_time DATETIME,        -- 交易时间
    counterparty_account VARCHAR(30), -- 对手账号
    channel_code    VARCHAR(10),      -- 渠道代码（01-柜面，02-ATM，03-网银，04-手机银行）
    batch_date      VARCHAR(10)       -- 数据批次日期
);

-- =============================================
-- 第二部分：数据质量校验存储过程
-- =============================================

-- =============================================
-- 存储过程：sp_validate_customer_data
-- 功能描述：客户数据质量校验
-- 校验规则：
--   1. 客户号不能为空且长度必须为15位
--   2. 证件类型必须在有效范围内
--   3. 身份证号码格式校验（18位）
--   4. 手机号码格式校验（11位数字）
--   5. 性别字段必须在有效范围内
--   6. 出生日期不能晚于当前日期
-- =============================================

DELIMITER //

CREATE PROCEDURE sp_validate_customer_data(
    IN p_batch_date VARCHAR(10),      -- 输入参数：数据批次日期
    OUT p_valid_count INT,            -- 输出参数：校验通过记录数
    OUT p_invalid_count INT           -- 输出参数：校验不通过记录数
)
BEGIN
    -- 声明变量
    DECLARE v_error_count INT DEFAULT 0;  -- 错误记录计数器
    
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT '客户数据校验过程中发生错误！' AS error_message;
        SET p_valid_count = 0;
        SET p_invalid_count = 0;
    END;
    
    -- 创建临时表存储校验结果
    DROP TABLE IF EXISTS tmp_customer_validate;
    CREATE TEMPORARY TABLE tmp_customer_validate (
        customer_id VARCHAR(20),
        error_type VARCHAR(50),
        error_desc VARCHAR(200)
    );
    
    -- =============================================
    -- 校验规则1：客户号不能为空且长度必须为15位
    -- =============================================
    INSERT INTO tmp_customer_validate
    SELECT 
        customer_id,
        '客户号校验失败',
        CONCAT('客户号长度不为15位，实际长度：', LENGTH(IFNULL(customer_id, '')))
    FROM ods_customer_info
    WHERE batch_date = p_batch_date
      AND (customer_id IS NULL 
           OR LENGTH(TRIM(customer_id)) != 15);
    
    -- =============================================
    -- 校验规则2：证件类型必须在有效范围内
    -- =============================================
    INSERT INTO tmp_customer_validate
    SELECT 
        customer_id,
        '证件类型校验失败',
        CONCAT('证件类型不在有效范围内，当前值：', IFNULL(id_type, 'NULL'))
    FROM ods_customer_info
    WHERE batch_date = p_batch_date
      AND id_type NOT IN ('01', '02', '03');
    
    -- =============================================
    -- 校验规则3：身份证号码格式校验（18位）
    -- =============================================
    INSERT INTO tmp_customer_validate
    SELECT 
        customer_id,
        '身份证号校验失败',
        CONCAT('身份证号格式不正确，当前长度：', LENGTH(IFNULL(id_no, '')))
    FROM ods_customer_info
    WHERE batch_date = p_batch_date
      AND id_type = '01'  -- 仅校验身份证类型
      AND (id_no IS NULL 
           OR LENGTH(TRIM(id_no)) != 18);
    
    -- =============================================
    -- 校验规则4：手机号码格式校验（11位数字）
    -- =============================================
    INSERT INTO tmp_customer_validate
    SELECT 
        customer_id,
        '手机号校验失败',
        CONCAT('手机号格式不正确，当前值：', IFNULL(mobile_phone, 'NULL'))
    FROM ods_customer_info
    WHERE batch_date = p_batch_date
      AND mobile_phone IS NOT NULL
      AND mobile_phone != ''
      AND (LENGTH(mobile_phone) != 11 
           OR mobile_phone NOT REGEXP '^[0-9]{11}$');
    
    -- =============================================
    -- 校验规则5：性别字段必须在有效范围内
    -- =============================================
    INSERT INTO tmp_customer_validate
    SELECT 
        customer_id,
        '性别校验失败',
        CONCAT('性别不在有效范围内，当前值：', IFNULL(gender, 'NULL'))
    FROM ods_customer_info
    WHERE batch_date = p_batch_date
      AND gender IS NOT NULL
      AND gender NOT IN ('M', 'F');
    
    -- =============================================
    -- 校验规则6：出生日期不能晚于当前日期
    -- =============================================
    INSERT INTO tmp_customer_validate
    SELECT 
        customer_id,
        '出生日期校验失败',
        CONCAT('出生日期晚于当前日期，当前值：', IFNULL(birth_date, 'NULL'))
    FROM ods_customer_info
    WHERE batch_date = p_batch_date
      AND birth_date IS NOT NULL
      AND birth_date > CURDATE();
    
    -- 统计校验结果
    SELECT COUNT(DISTINCT customer_id) INTO p_invalid_count
    FROM tmp_customer_validate;
    
    -- 计算校验通过记录数
    SELECT COUNT(*) - p_invalid_count INTO p_valid_count
    FROM ods_customer_info
    WHERE batch_date = p_batch_date;
    
    -- 输出校验报告
    SELECT 
        '客户数据质量校验报告' AS report_title,
        p_batch_date AS batch_date,
        p_valid_count AS valid_count,
        p_invalid_count AS invalid_count,
        ROUND(p_valid_count * 100.0 / (p_valid_count + p_invalid_count), 2) AS pass_rate;
    
    -- 输出详细错误信息
    SELECT * FROM tmp_customer_validate;
    
    -- 清理临时表
    DROP TEMPORARY TABLE IF EXISTS tmp_customer_validate;
    
END //

DELIMITER ;

-- =============================================
-- 存储过程：sp_validate_account_data
-- 功能描述：账户数据质量校验
-- 校验规则：
--   1. 账号不能为空
--   2. 客户号必须存在于客户信息表中
--   3. 账户类型必须在有效范围内
--   4. 币种必须在有效范围内
--   5. 开户日期不能晚于当前日期
--   6. 账户状态必须在有效范围内
--   7. 余额不能为负数
-- =============================================

DELIMITER //

CREATE PROCEDURE sp_validate_account_data(
    IN p_batch_date VARCHAR(10),
    OUT p_valid_count INT,
    OUT p_invalid_count INT
)
BEGIN
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT '账户数据校验过程中发生错误！' AS error_message;
        SET p_valid_count = 0;
        SET p_invalid_count = 0;
    END;
    
    -- 创建临时表存储校验结果
    DROP TABLE IF EXISTS tmp_account_validate;
    CREATE TEMPORARY TABLE tmp_account_validate (
        account_no VARCHAR(30),
        customer_id VARCHAR(20),
        error_type VARCHAR(50),
        error_desc VARCHAR(200)
    );
    
    -- =============================================
    -- 校验规则1：账号不能为空
    -- =============================================
    INSERT INTO tmp_account_validate
    SELECT 
        account_no,
        customer_id,
        '账号校验失败',
        '账号不能为空'
    FROM ods_account_info
    WHERE batch_date = p_batch_date
      AND (account_no IS NULL OR TRIM(account_no) = '');
    
    -- =============================================
    -- 校验规则2：客户号必须存在于客户信息表中
    -- =============================================
    INSERT INTO tmp_account_validate
    SELECT 
        a.account_no,
        a.customer_id,
        '客户号关联校验失败',
        CONCAT('客户号不存在于客户信息表中：', a.customer_id)
    FROM ods_account_info a
    LEFT JOIN ods_customer_info c ON a.customer_id = c.customer_id
    WHERE a.batch_date = p_batch_date
      AND c.customer_id IS NULL;
    
    -- =============================================
    -- 校验规则3：账户类型必须在有效范围内
    -- =============================================
    INSERT INTO tmp_account_validate
    SELECT 
        account_no,
        customer_id,
        '账户类型校验失败',
        CONCAT('账户类型不在有效范围内，当前值：', IFNULL(account_type, 'NULL'))
    FROM ods_account_info
    WHERE batch_date = p_batch_date
      AND account_type NOT IN ('01', '02', '03');
    
    -- =============================================
    -- 校验规则4：币种必须在有效范围内
    -- =============================================
    INSERT INTO tmp_account_validate
    SELECT 
        account_no,
        customer_id,
        '币种校验失败',
        CONCAT('币种不在有效范围内，当前值：', IFNULL(currency_code, 'NULL'))
    FROM ods_account_info
    WHERE batch_date = p_batch_date
      AND currency_code NOT IN ('CNY', 'USD', 'EUR', 'GBP');
    
    -- =============================================
    -- 校验规则5：开户日期不能晚于当前日期
    -- =============================================
    INSERT INTO tmp_account_validate
    SELECT 
        account_no,
        customer_id,
        '开户日期校验失败',
        CONCAT('开户日期晚于当前日期，当前值：', IFNULL(open_date, 'NULL'))
    FROM ods_account_info
    WHERE batch_date = p_batch_date
      AND open_date IS NOT NULL
      AND open_date > CURDATE();
    
    -- =============================================
    -- 校验规则6：账户状态必须在有效范围内
    -- =============================================
    INSERT INTO tmp_account_validate
    SELECT 
        account_no,
        customer_id,
        '账户状态校验失败',
        CONCAT('账户状态不在有效范围内，当前值：', IFNULL(status, 'NULL'))
    FROM ods_account_info
    WHERE batch_date = p_batch_date
      AND status NOT IN ('01', '02', '03');
    
    -- =============================================
    -- 校验规则7：余额不能为负数
    -- =============================================
    INSERT INTO tmp_account_validate
    SELECT 
        account_no,
        customer_id,
        '余额校验失败',
        CONCAT('账户余额为负数，当前值：', IFNULL(balance, 0))
    FROM ods_account_info
    WHERE batch_date = p_batch_date
      AND balance < 0;
    
    -- 统计校验结果
    SELECT COUNT(DISTINCT account_no) INTO p_invalid_count
    FROM tmp_account_validate;
    
    SELECT COUNT(*) - p_invalid_count INTO p_valid_count
    FROM ods_account_info
    WHERE batch_date = p_batch_date;
    
    -- 输出校验报告
    SELECT 
        '账户数据质量校验报告' AS report_title,
        p_batch_date AS batch_date,
        p_valid_count AS valid_count,
        p_invalid_count AS invalid_count;
    
    -- 输出详细错误信息
    SELECT * FROM tmp_account_validate;
    
    -- 清理临时表
    DROP TEMPORARY TABLE IF EXISTS tmp_account_validate;
    
END //

DELIMITER ;

-- =============================================
-- 存储过程：sp_validate_transaction_data
-- 功能描述：交易流水数据质量校验
-- 校验规则：
--   1. 交易流水号不能为空且必须唯一
--   2. 账号必须存在于账户信息表中
--   3. 交易类型必须在有效范围内
--   4. 交易金额必须大于0
--   5. 交易日期不能晚于当前日期
--   6. 转账交易必须有对手账号
-- =============================================

DELIMITER //

CREATE PROCEDURE sp_validate_transaction_data(
    IN p_batch_date VARCHAR(10),
    OUT p_valid_count BIGINT,
    OUT p_invalid_count BIGINT
)
BEGIN
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT '交易流水校验过程中发生错误！' AS error_message;
        SET p_valid_count = 0;
        SET p_invalid_count = 0;
    END;
    
    -- 创建临时表存储校验结果
    DROP TABLE IF EXISTS tmp_transaction_validate;
    CREATE TEMPORARY TABLE tmp_transaction_validate (
        transaction_id VARCHAR(30),
        account_no VARCHAR(30),
        error_type VARCHAR(50),
        error_desc VARCHAR(200)
    );
    
    -- =============================================
    -- 校验规则1：交易流水号不能为空且必须唯一
    -- =============================================
    INSERT INTO tmp_transaction_validate
    SELECT 
        transaction_id,
        account_no,
        '交易流水号校验失败',
        '交易流水号为空'
    FROM ods_transaction
    WHERE batch_date = p_batch_date
      AND (transaction_id IS NULL OR TRIM(transaction_id) = '');
    
    -- 检查重复的交易流水号
    INSERT INTO tmp_transaction_validate
    SELECT 
        t.transaction_id,
        t.account_no,
        '交易流水号重复',
        CONCAT('交易流水号重复，重复次数：', cnt)
    FROM ods_transaction t
    INNER JOIN (
        SELECT transaction_id, COUNT(*) AS cnt
        FROM ods_transaction
        WHERE batch_date = p_batch_date
        GROUP BY transaction_id
        HAVING COUNT(*) > 1
    ) dup ON t.transaction_id = dup.transaction_id
    WHERE t.batch_date = p_batch_date;
    
    -- =============================================
    -- 校验规则2：账号必须存在于账户信息表中
    -- =============================================
    INSERT INTO tmp_transaction_validate
    SELECT 
        t.transaction_id,
        t.account_no,
        '账号关联校验失败',
        CONCAT('账号不存在于账户信息表中：', t.account_no)
    FROM ods_transaction t
    LEFT JOIN ods_account_info a ON t.account_no = a.account_no
    WHERE t.batch_date = p_batch_date
      AND a.account_no IS NULL;
    
    -- =============================================
    -- 校验规则3：交易类型必须在有效范围内
    -- =============================================
    INSERT INTO tmp_transaction_validate
    SELECT 
        transaction_id,
        account_no,
        '交易类型校验失败',
        CONCAT('交易类型不在有效范围内，当前值：', IFNULL(transaction_type, 'NULL'))
    FROM ods_transaction
    WHERE batch_date = p_batch_date
      AND transaction_type NOT IN ('01', '02', '03');
    
    -- =============================================
    -- 校验规则4：交易金额必须大于0
    -- =============================================
    INSERT INTO tmp_transaction_validate
    SELECT 
        transaction_id,
        account_no,
        '交易金额校验失败',
        CONCAT('交易金额不大于0，当前值：', IFNULL(transaction_amt, 0))
    FROM ods_transaction
    WHERE batch_date = p_batch_date
      AND transaction_amt <= 0;
    
    -- =============================================
    -- 校验规则5：交易日期不能晚于当前日期
    -- =============================================
    INSERT INTO tmp_transaction_validate
    SELECT 
        transaction_id,
        account_no,
        '交易日期校验失败',
        CONCAT('交易日期晚于当前日期，当前值：', IFNULL(transaction_date, 'NULL'))
    FROM ods_transaction
    WHERE batch_date = p_batch_date
      AND transaction_date > CURDATE();
    
    -- =============================================
    -- 校验规则6：转账交易必须有对手账号
    -- =============================================
    INSERT INTO tmp_transaction_validate
    SELECT 
        transaction_id,
        account_no,
        '对手账号校验失败',
        '转账交易缺少对手账号'
    FROM ods_transaction
    WHERE batch_date = p_batch_date
      AND transaction_type = '03'  -- 转账交易
      AND (counterparty_account IS NULL OR TRIM(counterparty_account) = '');
    
    -- 统计校验结果
    SELECT COUNT(DISTINCT transaction_id) INTO p_invalid_count
    FROM tmp_transaction_validate;
    
    SELECT COUNT(*) - p_invalid_count INTO p_valid_count
    FROM ods_transaction
    WHERE batch_date = p_batch_date;
    
    -- 输出校验报告
    SELECT 
        '交易流水数据质量校验报告' AS report_title,
        p_batch_date AS batch_date,
        p_valid_count AS valid_count,
        p_invalid_count AS invalid_count;
    
    -- 输出详细错误信息
    SELECT * FROM tmp_transaction_validate;
    
    -- 清理临时表
    DROP TEMPORARY TABLE IF EXISTS tmp_transaction_validate;
    
END //

DELIMITER ;

-- =============================================
-- 第三部分：数据清洗转换存储过程
-- =============================================

-- =============================================
-- 存储过程：sp_etl_customer_to_dwd
-- 功能描述：将ODS层客户数据清洗转换到DWD层
-- 处理逻辑：
--   1. 数据去重（取最新一条）
--   2. 字段标准化处理
--   3. 数据脱敏处理（身份证号、手机号）
-- =============================================

DELIMITER //

CREATE PROCEDURE sp_etl_customer_to_dwd(
    IN p_batch_date VARCHAR(10),
    OUT p_process_count INT
)
BEGIN
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT '客户数据ETL处理过程中发生错误！' AS error_message;
        SET p_process_count = 0;
        ROLLBACK;  -- 发生异常时回滚事务
    END;
    
    -- 开启事务
    START TRANSACTION;
    
    -- 创建DWD层客户信息表
    DROP TABLE IF EXISTS dwd_customer_info;
    CREATE TABLE dwd_customer_info (
        customer_id     VARCHAR(20),
        customer_name   VARCHAR(100),
        id_type         VARCHAR(10),
        id_no_masked    VARCHAR(30),    -- 脱敏后的身份证号
        gender          VARCHAR(2),
        age             INT,            -- 根据出生日期计算年龄
        mobile_masked   VARCHAR(20),    -- 脱敏后的手机号
        email           VARCHAR(100),
        create_time     DATETIME,
        etl_time        DATETIME        -- ETL处理时间
    );
    
    -- 数据清洗转换
    INSERT INTO dwd_customer_info
    SELECT 
        customer_id,
        TRIM(customer_name) AS customer_name,
        id_type,
        -- 身份证号脱敏：保留前3位和后4位
        CONCAT(LEFT(id_no, 3), '***********', RIGHT(id_no, 4)) AS id_no_masked,
        CASE 
            WHEN gender = 'M' THEN '男'
            WHEN gender = 'F' THEN '女'
            ELSE '未知'
        END AS gender,
        -- 计算年龄
        TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) AS age,
        -- 手机号脱敏：保留前3位和后4位
        CONCAT(LEFT(mobile_phone, 3), '****', RIGHT(mobile_phone, 4)) AS mobile_masked,
        LOWER(TRIM(email)) AS email,
        create_time,
        NOW() AS etl_time
    FROM (
        -- 数据去重：按客户号分组，取更新时间最新的一条
        SELECT 
            *,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY update_time DESC) AS rn
        FROM ods_customer_info
        WHERE batch_date = p_batch_date
          AND customer_id IS NOT NULL
          AND LENGTH(TRIM(customer_id)) = 15
    ) t
    WHERE rn = 1;
    
    -- 获取处理记录数
    SELECT COUNT(*) INTO p_process_count
    FROM dwd_customer_info;
    
    -- 提交事务
    COMMIT;
    
    -- 输出处理结果
    SELECT 
        '客户数据ETL处理报告' AS report_title,
        p_batch_date AS batch_date,
        p_process_count AS process_count,
        NOW() AS etl_time;
    
END //

DELIMITER ;

-- =============================================
-- 第四部分：综合数据质量检查存储过程
-- =============================================

-- =============================================
-- 存储过程：sp_data_quality_check
-- 功能描述：执行全量数据质量检查
-- =============================================

DELIMITER //

CREATE PROCEDURE sp_data_quality_check(
    IN p_batch_date VARCHAR(10)
)
BEGIN
    -- 声明变量存储各表校验结果
    DECLARE v_customer_valid INT;
    DECLARE v_customer_invalid INT;
    DECLARE v_account_valid INT;
    DECLARE v_account_invalid INT;
    DECLARE v_transaction_valid BIGINT;
    DECLARE v_transaction_invalid BIGINT;
    
    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT '数据质量检查过程中发生错误！' AS error_message;
    END;
    
    -- 输出检查开始信息
    SELECT CONCAT('开始执行数据质量检查，批次日期：', p_batch_date) AS start_message;
    
    -- 校验客户数据
    CALL sp_validate_customer_data(p_batch_date, v_customer_valid, v_customer_invalid);
    
    -- 校验账户数据
    CALL sp_validate_account_data(p_batch_date, v_account_valid, v_account_invalid);
    
    -- 校验交易数据
    CALL sp_validate_transaction_data(p_batch_date, v_transaction_valid, v_transaction_invalid);
    
    -- 输出汇总报告
    SELECT 
        '数据质量检查汇总报告' AS report_title,
        p_batch_date AS batch_date,
        v_customer_valid AS customer_valid,
        v_customer_invalid AS customer_invalid,
        v_account_valid AS account_valid,
        v_account_invalid AS account_invalid,
        v_transaction_valid AS transaction_valid,
        v_transaction_invalid AS transaction_invalid,
        NOW() AS check_time;
    
    -- 输出检查完成信息
    SELECT '数据质量检查完成！' AS end_message;
    
END //

DELIMITER ;

-- =============================================
-- 调用示例
-- =============================================

-- 示例1：执行客户数据校验
-- CALL sp_validate_customer_data('2026-09-21', @valid, @invalid);
-- SELECT @valid AS 通过记录数, @invalid AS 不通过记录数;

-- 示例2：执行账户数据校验
-- CALL sp_validate_account_data('2026-09-21', @valid, @invalid);
-- SELECT @valid AS 通过记录数, @invalid AS 不通过记录数;

-- 示例3：执行交易流水校验
-- CALL sp_validate_transaction_data('2026-09-21', @valid, @invalid);
-- SELECT @valid AS 通过记录数, @invalid AS 不通过记录数;

-- 示例4：执行客户数据ETL
-- CALL sp_etl_customer_to_dwd('2026-09-21', @count);
-- SELECT @count AS 处理记录数;

-- 示例5：执行全量数据质量检查
-- CALL sp_data_quality_check('2026-09-21');
