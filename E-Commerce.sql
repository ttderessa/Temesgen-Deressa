-- Customers table
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    Name VARCHAR(100),
    Country VARCHAR(50)
);

INSERT INTO Customers VALUES
(1, 'Alice', 'USA'),
(2, 'Bob', 'Canada'),
(3, 'Charlie', 'USA'),
(4, 'Diana', 'UK');

-- Orders table
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT,
    OrderDate DATE,
    TotalAmount DECIMAL(10, 2),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

INSERT INTO Orders VALUES
(101, 1, '2024-01-15', 120.00),
(102, 2, '2024-01-17', 200.00),
(103, 1, '2024-02-05', 75.00),
(104, 3, '2024-02-20', 50.00),
(105, 4, '2024-03-10', 300.00),
(106, 1, '2024-03-12', 180.00);


WITH MonthlySpending AS (
    SELECT 
        c.CustomerID,
        c.Name,
        FORMAT(o.OrderDate, 'yyyy-MM') AS OrderMonth, 
        SUM(o.TotalAmount) AS MonthlyTotal
    FROM Orders o
    JOIN Customers c ON o.CustomerID = c.CustomerID
    GROUP BY c.CustomerID, c.Name, FORMAT(o.OrderDate, 'yyyy-MM')
),

RankedSpending AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY OrderMonth) AS rn
    FROM MonthlySpending
),

SpendingWithLag AS (
    SELECT 
        a.CustomerID,
        a.Name,
        a.OrderMonth,
        a.MonthlyTotal,
        b.MonthlyTotal AS PrevMonthTotal,
        ROUND(
            CASE 
                WHEN b.MonthlyTotal IS NOT NULL AND b.MonthlyTotal > 0 THEN 
                    ((a.MonthlyTotal - b.MonthlyTotal) / b.MonthlyTotal) * 100
                ELSE NULL
            END, 2
        ) AS MoM_Growth_Percent
    FROM RankedSpending a
    LEFT JOIN RankedSpending b
        ON a.CustomerID = b.CustomerID AND a.rn = b.rn + 1
),

Filtered AS (
    SELECT CustomerID
    FROM MonthlySpending
    GROUP BY CustomerID
    HAVING COUNT(*) >= 2
)

SELECT 
    s.Name,
    s.OrderMonth,
    s.MonthlyTotal,
    s.PrevMonthTotal,
    s.MoM_Growth_Percent
FROM SpendingWithLag s
JOIN Filtered f ON s.CustomerID = f.CustomerID
ORDER BY s.Name, s.OrderMonth;