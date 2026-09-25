-- =============================================
-- 文件名：1.sql
-- 功能描述：基于sales表的存储过程示例集合
-- 创建日期：2026-09-21
-- =============================================

-- =============================================
-- 存储过程1：sp_get_department_summary
-- 功能描述：获取指定部门的销售统计信息
-- 参数说明：
--   IN  p_dept_name    - 部门名称（输入参数）
--   OUT p_total_amount - 该部门总销售额（输出参数）
--   OUT p_employee_count - 该部门员工数量（输出参数）
-- =============================================

DELIMITER //

CREATE PROCEDURE sp_get_department_summary(
    IN p_dept_name VARCHAR(20),        -- 输入参数：部门名称
    OUT p_total_amount DECIMAL(10,2),  -- 输出参数：部门总销售额
    OUT p_employee_count INT           -- 输出参数：部门员工数量
)
BEGIN
    -- 声明局部变量用于存储统计结果
    DECLARE v_avg_amount DECIMAL(10,2);  -- 平均销售额
    DECLARE v_max_amount DECIMAL(10,2);  -- 最高销售额
    DECLARE v_min_amount DECIMAL(10,2);  -- 最低销售额
    
    -- 异常处理：如果发生SQL异常，执行以下操作
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- 发生异常时，输出错误信息并设置默认值
        SELECT '查询出错，请检查部门名称是否正确' AS error_message;
        SET p_total_amount = 0;
        SET p_employee_count = 0;
    END;
    
    -- 查询部门统计信息
    -- 使用聚合函数计算总销售额、员工数量、平均/最高/最低销售额
    SELECT 
        SUM(amount),              -- 计算总销售额
        COUNT(DISTINCT employee), -- 统计不重复的员工数量
        AVG(amount),              -- 计算平均销售额
        MAX(amount),              -- 找出最高销售额
        MIN(amount)               -- 找出最低销售额
    INTO 
        p_total_amount,           -- 将结果赋值给输出参数
        p_employee_count,
        v_avg_amount,
        v_max_amount,
        v_min_amount
    FROM sales
    WHERE department = p_dept_name;  -- 按部门名称筛选
    
    -- 输出详细的统计报告
    SELECT 
        p_dept_name AS '部门名称',
        p_employee_count AS '员工数量',
        p_total_amount AS '总销售额',
        v_avg_amount AS '平均销售额',
        v_max_amount AS '最高销售额',
        v_min_amount AS '最低销售额';
    
    -- 根据总销售额给出部门评价（条件判断）
    IF p_total_amount > 10000 THEN
        SELECT '优秀部门：销售额超过10000！' AS evaluation;
    ELSEIF p_total_amount > 5000 THEN
        SELECT '良好部门：销售额在5000-10000之间' AS evaluation;
    ELSE
        SELECT '待改进部门：销售额低于5000' AS evaluation;
    END IF;
    
END //

DELIMITER ;

-- =============================================
-- 存储过程2：sp_insert_sales_batch
-- 功能描述：批量插入销售记录
-- 参数说明：
--   IN p_dept     - 部门名称
--   IN p_employee - 员工姓名
--   IN p_amount   - 销售金额
--   IN p_count    - 插入记录的数量
-- =============================================

DELIMITER //

CREATE PROCEDURE sp_insert_sales_batch(
    IN p_dept VARCHAR(20),
    IN p_employee VARCHAR(20),
    IN p_amount DECIMAL(10,2),
    IN p_count INT  -- 插入记录的数量
)
BEGIN
    DECLARE i INT DEFAULT 1;  -- 循环计数器，初始值为1
    
    -- 开启事务，确保数据一致性
    -- 事务保证要么全部成功，要么全部回滚
    START TRANSACTION;
    
    -- 循环插入指定数量的记录
    WHILE i <= p_count DO
        INSERT INTO sales (department, employee, amount)
        VALUES (p_dept, p_employee, p_amount);
        
        SET i = i + 1;  -- 计数器加1
    END WHILE;
    
    -- 提交事务（确认所有更改）
    COMMIT;
    
    -- 返回插入成功的消息
    SELECT CONCAT('成功插入 ', p_count, ' 条记录') AS result_message;
END //

DELIMITER ;

-- =============================================
-- 存储过程3：sp_update_employee_amount
-- 功能描述：更新指定员工的销售额
-- 参数说明：
--   IN p_employee   - 员工姓名
--   IN p_new_amount - 新的销售额
-- =============================================

DELIMITER //

CREATE PROCEDURE sp_update_employee_amount(
    IN p_employee VARCHAR(20),
    IN p_new_amount DECIMAL(10,2)
)
BEGIN
    -- 更新指定员工的销售额
    UPDATE sales
    SET amount = p_new_amount
    WHERE employee = p_employee;
    
    -- 检查是否更新成功（ROW_COUNT()返回受影响的行数）
    IF ROW_COUNT() > 0 THEN
        SELECT CONCAT('员工 ', p_employee, ' 的销售额已更新为 ', p_new_amount) AS result_message;
    ELSE
        SELECT CONCAT('未找到员工：', p_employee) AS result_message;
    END IF;
END //

DELIMITER ;

-- =============================================
-- 存储过程4：sp_get_top_employees
-- 功能描述：获取各部门销售额排名前N的员工
-- 参数说明：
--   IN p_dept - 部门名称（可选，为空则查询所有部门）
--   IN p_top_n - 排名数量
-- =============================================

DELIMITER //

CREATE PROCEDURE sp_get_top_employees(
    IN p_dept VARCHAR(20),
    IN p_top_n INT
)
BEGIN
    -- 判断是否指定了部门
    IF p_dept IS NULL OR p_dept = '' THEN
        -- 未指定部门，查询所有部门的前N名
        SELECT 
            department AS '部门',
            employee AS '员工',
            amount AS '销售额',
            rn AS '排名'
        FROM (
            SELECT 
                department,
                employee,
                amount,
                ROW_NUMBER() OVER (PARTITION BY department ORDER BY amount DESC) AS rn
            FROM sales
        ) ranked
        WHERE rn <= p_top_n
        ORDER BY department, rn;
    ELSE
        -- 指定了部门，只查询该部门的前N名
        SELECT 
            department AS '部门',
            employee AS '员工',
            amount AS '销售额',
            ROW_NUMBER() OVER (ORDER BY amount DESC) AS '排名'
        FROM sales
        WHERE department = p_dept
        ORDER BY amount DESC
        LIMIT p_top_n;
    END IF;
END //

DELIMITER ;

-- =============================================
-- 调用示例
-- =============================================

-- 示例1：查询研发部的统计信息
-- CALL sp_get_department_summary('研发部', @total, @count);
-- SELECT @total AS 总销售额, @count AS 员工数量;

-- 示例2：查询市场部的统计信息
-- CALL sp_get_department_summary('市场部', @total, @count);
-- SELECT @total AS 总销售额, @count AS 员工数量;

-- 示例3：批量插入5条记录
-- CALL sp_insert_sales_batch('研发部', '新员工', 3000, 5);

-- 示例4：更新员工销售额
-- CALL sp_update_employee_amount('张三', 6000);

-- 示例5：获取各部门销售额前2名的员工
-- CALL sp_get_top_employees(NULL, 2);

-- 示例6：获取研发部销售额前3名的员工
-- CALL sp_get_top_employees('研发部', 3);
