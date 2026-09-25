-- 建表并插入一些示例数据
DROP TABLE IF EXISTS sales;
CREATE TABLE sales (
    id          INT,
    department  VARCHAR(20),
    employee    VARCHAR(20),
    amount      DECIMAL(10,2)
);

INSERT INTO sales VALUES
(1, '研发部', '张三', 3000),
(2, '研发部', '李四', 5000),
(3, '研发部', '王五', 5000),
(4, '市场部', '赵六', 4000),
(5, '市场部', '钱七', 4000),
(6, '市场部', '孙八', 6000);

/*
 * 开窗函数示例：
 * 1. ROW_NUMBER()  - 分组内按金额排序生成唯一序号（即使金额相同序号也不同）
 * 2. RANK()        - 分组内排名（金额相同排名相同，会跳号：1,2,2,4）
 * 3. DENSE_RANK()  - 分组内密集排名（金额相同排名相同，不跳号：1,2,2,3）
 * 4. SUM() OVER()  - 分组内累计求和（每行都是截止当前的累计总额）
 */
SELECT
    department,
    employee,
    amount,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY amount DESC) AS rn,
    RANK()       OVER (PARTITION BY department ORDER BY amount DESC) AS rk,
    DENSE_RANK() OVER (PARTITION BY department ORDER BY amount DESC) AS drk,
    SUM(amount)  OVER (PARTITION BY department ORDER BY amount DESC
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM sales
ORDER BY department, amount DESC;