# 📊 BI Rate, Inflation & Macroeconomic Indicators Analysis with SQL

This project analyzes Indonesia's macroeconomic conditions by integrating and querying multiple economic datasets using advanced SQL techniques in PostgreSQL through DBeaver. The analysis focuses on the relationship between the **Bank Indonesia (BI) Interest Rate**, **Inflation (YoY)**, **USD/IDR Exchange Rate**, and **Foreign Exchange Reserves** to identify economic trends and generate data-driven insights.

---

# 🚀 Features

- Multi-table data integration using SQL JOINs
- Annual aggregation of macroeconomic indicators
- BI Rate trend detection using Window Functions
- Event study analysis before and after BI Rate changes
- Pearson correlation analysis between economic indicators
- Monthly exchange rate depreciation analysis
- Recent macroeconomic trend monitoring
- Exchange rate volatility analysis using Standard Deviation
- Advanced SQL implementation using CTEs, Window Functions, Aggregate Functions, and Statistical Functions
- Tableau-ready output for interactive dashboard visualization

---

# 📈 Workflow

```text
Raw CSV Datasets
        │
        ▼
Import into PostgreSQL
        │
        ▼
Data Integration
(SQL JOIN)
        │
        ▼
Data Aggregation
(GROUP BY)
        │
        ▼
Time-Series Analysis
(Window Functions)
        │
        ▼
Statistical Analysis
(CORR, STDDEV)
        │
        ▼
Event Study
(Before vs After BI Rate Changes)
        │
        ▼
Business Insights
        │
        ▼
Interactive Dashboard
(Tableau)
```

---

# 🛠 Technologies

- PostgreSQL
- SQL
- DBeaver
- Tableau
- CSV
- Common Table Expressions (CTE)
- Window Functions
- Aggregate Functions
- Statistical Functions
- Time-Series Analysis

---

# 📌 SQL Analysis Overview

The following sections describe the primary SQL analyses implemented throughout this project.

## 🔍 1. Complete Dataset Integration (LEFT JOIN)

This query integrates the time dimension table with multiple macroeconomic fact tables using **LEFT JOIN**, ensuring that all financial indicators are synchronized by reporting period.

```sql
SELECT
    dw.periode, dw.tahun, dw.nama_bulan, dw.kuartal,
    br.bi_rate, k.kurs_usdidr_avg,
    inf.inflasi_yoy, cd.cadangan_devisa_miliar_usd
FROM dim_waktu dw
LEFT JOIN fakta_bi_rate br ON dw.periode_id = br.periode_id
LEFT JOIN fakta_kurs k ON dw.periode_id = k.periode_id
LEFT JOIN fakta_inflasi inf ON dw.periode_id = inf.periode_id
LEFT JOIN fakta_cadangan_devisa cd ON dw.periode_id = cd.periode_id
ORDER BY dw.periode;
```

---

## 📈 2. Annual Financial Indicator Aggregation

Calculates annual average values for BI Rate, exchange rate, inflation, and foreign exchange reserves to identify long-term macroeconomic trends.

```sql
SELECT
    dw.tahun,
    ROUND(AVG(br.bi_rate), 2) AS avg_bi_rate,
    ROUND(AVG(k.kurs_usdidr_avg), 0) AS avg_kurs,
    ROUND(AVG(inf.inflasi_yoy), 2) AS avg_inflasi,
    ROUND(AVG(cd.cadangan_devisa_miliar_usd), 1) AS avg_foreign_reserves
FROM dim_waktu dw
LEFT JOIN fakta_bi_rate br ON dw.periode_id = br.periode_id
LEFT JOIN fakta_kurs k ON dw.periode_id = k.periode_id
LEFT JOIN fakta_inflasi inf ON dw.periode_id = inf.periode_id
LEFT JOIN fakta_cadangan_devisa cd ON dw.periode_id = cd.periode_id
GROUP BY dw.tahun
ORDER BY dw.tahun;
```

---

## 🔄 3. BI Rate Trend Detection (LAG Window Function)

Uses the **LAG()** window function to compare the current BI Rate with the previous reporting period, allowing changes in monetary policy direction to be identified.

```sql
WITH rate_seq AS (
    SELECT
        dw.periode,
        br.bi_rate,
        LAG(br.bi_rate) OVER (ORDER BY dw.periode) AS previous_rate
    FROM dim_waktu dw
    JOIN fakta_bi_rate br
        ON dw.periode_id = br.periode_id
)
SELECT
    periode,
    bi_rate,
    previous_rate,
    bi_rate - previous_rate AS difference,
    CASE
        WHEN bi_rate > previous_rate THEN 'INCREASE'
        WHEN bi_rate < previous_rate THEN 'DECREASE'
        ELSE 'UNCHANGED'
    END AS movement
FROM rate_seq
WHERE previous_rate IS NOT NULL
  AND bi_rate <> previous_rate
ORDER BY periode;
```

---

## 📅 4. Event Study Analysis

Performs an event study by comparing the average USD/IDR exchange rate during the three months before and after each BI Rate adjustment.

```sql
WITH perubahan_rate AS (
    SELECT
        dw.periode,
        dw.periode_id,
        br.bi_rate,
        LAG(br.bi_rate) OVER (ORDER BY dw.periode) AS rate_sebelumnya
    FROM dim_waktu dw
    JOIN fakta_bi_rate br
        ON dw.periode_id = br.periode_id
),
event_dates AS (
    SELECT
        periode AS tanggal_event,
        periode_id AS event_periode_id,
        CASE
            WHEN bi_rate > rate_sebelumnya THEN 'NAIK'
            ELSE 'TURUN'
        END AS jenis_event
    FROM perubahan_rate
    WHERE rate_sebelumnya IS NOT NULL
      AND bi_rate <> rate_sebelumnya
)
SELECT
    e.tanggal_event,
    e.jenis_event,
    ROUND(AVG(
        CASE
            WHEN dw.periode_id BETWEEN e.event_periode_id-3
            AND e.event_periode_id-1
            THEN k.kurs_usdidr_avg
        END),0) AS kurs_avg_3bln_sebelum,

    ROUND(AVG(
        CASE
            WHEN dw.periode_id BETWEEN e.event_periode_id
            AND e.event_periode_id+2
            THEN k.kurs_usdidr_avg
        END),0) AS kurs_avg_3bln_sesudah

FROM event_dates e
JOIN dim_waktu dw
ON dw.periode_id BETWEEN e.event_periode_id-3
AND e.event_periode_id+2

JOIN fakta_kurs k
ON dw.periode_id = k.periode_id

GROUP BY
e.tanggal_event,
e.jenis_event

ORDER BY
e.tanggal_event;
```

---

## 📊 5. Correlation Analysis (CORR)

Calculates Pearson correlation coefficients to measure the strength of relationships between BI Rate, inflation, and the USD/IDR exchange rate.

```sql
SELECT
    ROUND(CORR(br.bi_rate, k.kurs_usdidr_avg)::numeric,3)
        AS correlation_rate_vs_exchange,

    ROUND(CORR(br.bi_rate, inf.inflasi_yoy)::numeric,3)
        AS correlation_rate_vs_inflation,

    ROUND(CORR(k.kurs_usdidr_avg, inf.inflasi_yoy)::numeric,3)
        AS correlation_exchange_vs_inflation

FROM dim_waktu dw
JOIN fakta_bi_rate br
ON dw.periode_id = br.periode_id

JOIN fakta_kurs k
ON dw.periode_id = k.periode_id

JOIN fakta_inflasi inf
ON dw.periode_id = inf.periode_id;
```

---

## 📉 6. Top 10 Monthly Currency Depreciation

Identifies the ten largest monthly depreciations of the Indonesian Rupiah against the US Dollar.

```sql
WITH kurs_seq AS (
    SELECT
        dw.periode,
        k.kurs_usdidr_avg,
        LAG(k.kurs_usdidr_avg)
        OVER (ORDER BY dw.periode)
        AS kurs_bulan_lalu

    FROM dim_waktu dw
    JOIN fakta_kurs k
    ON dw.periode_id = k.periode_id
)

SELECT
    periode,
    kurs_usdidr_avg,
    kurs_bulan_lalu,

    ROUND(
        (
        (kurs_usdidr_avg-kurs_bulan_lalu)
        /kurs_bulan_lalu*100
        )::numeric,2
    ) AS depreciation_percentage

FROM kurs_seq

WHERE kurs_bulan_lalu IS NOT NULL

ORDER BY depreciation_percentage DESC

LIMIT 10;
```

---

## 📈 7. Recent Economic Trend Analysis

Examines recent BI Rate, exchange rate, inflation, and foreign reserve movements to monitor current macroeconomic conditions.

```sql
SELECT
    dw.periode,
    br.bi_rate,
    k.kurs_usdidr_avg,
    inf.inflasi_yoy,
    cd.cadangan_devisa_miliar_usd,

    LAG(cd.cadangan_devisa_miliar_usd)
    OVER (ORDER BY dw.periode)
    - cd.cadangan_devisa_miliar_usd
    AS reserve_change

FROM dim_waktu dw

LEFT JOIN fakta_bi_rate br
ON dw.periode_id = br.periode_id

LEFT JOIN fakta_kurs k
ON dw.periode_id = k.periode_id

LEFT JOIN fakta_inflasi inf
ON dw.periode_id = inf.periode_id

LEFT JOIN fakta_cadangan_devisa cd
ON dw.periode_id = cd.periode_id

WHERE dw.periode >= '2025-05-01'

ORDER BY dw.periode;
```

---

## ⚡ 8. Annual Exchange Rate Volatility

Measures yearly exchange rate volatility using the SQL **STDDEV()** function while also identifying the minimum and maximum exchange rates recorded each year.

```sql
SELECT
    dw.tahun,

    ROUND(STDDEV(k.kurs_usdidr_avg)::numeric,0)
    AS exchange_rate_volatility,

    ROUND(MIN(k.kurs_usdidr_avg)::numeric,0)
    AS minimum_exchange_rate,

    ROUND(MAX(k.kurs_usdidr_avg)::numeric,0)
    AS maximum_exchange_rate

FROM dim_waktu dw

JOIN fakta_kurs k
ON dw.periode_id = k.periode_id

GROUP BY dw.tahun

ORDER BY exchange_rate_volatility DESC;
```

---

# 📂 Project Structure

```text
.
├── BI_query.sql
├── README.md
├── data/
│   ├── bi_rate.csv
│   ├── inflation.csv
│   ├── exchange_rate.csv
│   └── foreign_reserves.csv
└── dashboard/
    ├── tableau_dashboard.twb
    └── dashboard_preview.png
```

---

# ⚙ Installation

### 1. Clone the repository

```bash
git clone https://github.com/AlAkbar44/Bi-Rate-Analysis.git
```

### 2. Open the project

```bash
cd Bi-Rate-Analysis
```

### 3. Import the datasets

Import all CSV files into **PostgreSQL**, then execute the SQL script using **DBeaver**.

---

# 📊 Analysis Output

The project provides:

- Integrated macroeconomic dataset
- Annual BI Rate summary
- Inflation trend analysis
- Exchange rate analysis
- Event study results
- Correlation analysis
- Currency depreciation ranking
- Exchange rate volatility analysis
- Interactive Tableau dashboard

---

# 👨‍💻 Author

**Al Akbar Himawan**

Junior Data Analyst | SQL | PostgreSQL | Tableau | Business Intelligence

- GitHub: https://github.com/AlAkbar44
- LinkedIn: https://www.linkedin.com/in/alakbarhimawan
- Email: himawanalakbar6@gmail.com

