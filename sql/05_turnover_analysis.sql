CREATE OR REPLACE VIEW turnover_monthly AS
WITH monthly AS (
    SELECT
        m.month_start,
        m.month_end,
        COUNT(*) FILTER (
            WHERE e.hire_date < m.month_start
              AND (e.termination_date IS NULL OR e.termination_date >= m.month_start)
        ) AS opening_headcount,
        COUNT(*) FILTER (
            WHERE e.hire_date <= m.month_end
              AND (e.termination_date IS NULL OR e.termination_date > m.month_end)
        ) AS closing_headcount,
        COUNT(*) FILTER (WHERE e.termination_date BETWEEN m.month_start AND m.month_end) AS separations,
        COUNT(*) FILTER (
            WHERE e.termination_date BETWEEN m.month_start AND m.month_end
              AND e.termination_type = 'Voluntary'
        ) AS voluntary_separations
    FROM reporting_months AS m
    CROSS JOIN employees AS e
    GROUP BY m.month_start, m.month_end
)
SELECT
    month_start,
    opening_headcount,
    closing_headcount,
    (opening_headcount + closing_headcount) / 2.0 AS average_headcount,
    separations,
    voluntary_separations,
    ROUND(100.0 * separations / NULLIF((opening_headcount + closing_headcount) / 2.0, 0), 2) AS monthly_turnover_pct
FROM monthly
ORDER BY month_start;

CREATE OR REPLACE VIEW turnover_annual AS
SELECT
    YEAR(month_start) AS calendar_year,
    ROUND(AVG(closing_headcount), 1) AS average_month_end_headcount,
    SUM(separations) AS separations,
    SUM(voluntary_separations) AS voluntary_separations,
    SUM(separations) - SUM(voluntary_separations) AS involuntary_separations,
    ROUND(100.0 * SUM(separations) / AVG(closing_headcount), 1) AS annual_turnover_pct,
    ROUND(100.0 * SUM(voluntary_separations) / AVG(closing_headcount), 1) AS voluntary_turnover_pct,
    ROUND(100.0 * (SUM(separations) - SUM(voluntary_separations)) / AVG(closing_headcount), 1)
        AS involuntary_turnover_pct
FROM turnover_monthly
GROUP BY YEAR(month_start)
ORDER BY calendar_year;

CREATE OR REPLACE VIEW turnover_annual_trend AS
SELECT
    calendar_year,
    annual_turnover_pct,
    LAG(annual_turnover_pct) OVER (ORDER BY calendar_year) AS prior_year_turnover_pct,
    ROUND(annual_turnover_pct - LAG(annual_turnover_pct) OVER (ORDER BY calendar_year), 1)
        AS change_in_percentage_points,
    ROUND(AVG(annual_turnover_pct) OVER (ORDER BY calendar_year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1)
        AS three_year_moving_average_pct
FROM turnover_annual
ORDER BY calendar_year;

CREATE OR REPLACE VIEW turnover_department_monthly AS
SELECT
    m.month_start,
    d.department_name,
    COUNT(e.employee_id) FILTER (
        WHERE e.hire_date <= m.month_end
          AND (e.termination_date IS NULL OR e.termination_date > m.month_end)
    ) AS closing_headcount,
    COUNT(e.employee_id) FILTER (WHERE e.termination_date BETWEEN m.month_start AND m.month_end) AS separations
FROM reporting_months AS m
CROSS JOIN departments AS d
LEFT JOIN employee_details AS e ON e.department_id = d.department_id
GROUP BY m.month_start, d.department_name
ORDER BY m.month_start, d.department_name;

CREATE OR REPLACE VIEW turnover_by_department_annual AS
SELECT
    YEAR(month_start) AS calendar_year,
    department_name,
    ROUND(AVG(closing_headcount), 1) AS average_month_end_headcount,
    SUM(separations) AS separations,
    ROUND(100.0 * SUM(separations) / NULLIF(AVG(closing_headcount), 0), 1) AS annual_turnover_pct
FROM turnover_department_monthly
GROUP BY YEAR(month_start), department_name
ORDER BY calendar_year, department_name;

CREATE OR REPLACE VIEW turnover_by_department_recent AS
WITH windowed AS (
    SELECT
        department_name,
        AVG(closing_headcount) AS average_month_end_headcount,
        SUM(separations) AS separations,
        COUNT(DISTINCT YEAR(month_start)) AS years_in_window
    FROM turnover_department_monthly
    WHERE month_start >= DATE_TRUNC('year', as_of_date()) - INTERVAL 2 YEAR
    GROUP BY department_name
)
SELECT
    department_name,
    ROUND(average_month_end_headcount, 1) AS average_month_end_headcount,
    separations,
    ROUND(100.0 * separations / average_month_end_headcount / years_in_window, 1) AS annualized_turnover_pct,
    RANK() OVER (ORDER BY separations / average_month_end_headcount DESC) AS turnover_rank,
    CASE WHEN average_month_end_headcount < 30 THEN 'Small population' ELSE 'Adequate population' END
        AS population_note
FROM windowed
ORDER BY turnover_rank;

CREATE OR REPLACE VIEW turnover_by_employment_type_recent AS
WITH monthly AS (
    SELECT
        m.month_start,
        t.employment_type,
        COUNT(e.employee_id) FILTER (
            WHERE e.hire_date <= m.month_end
              AND (e.termination_date IS NULL OR e.termination_date > m.month_end)
        ) AS closing_headcount,
        COUNT(e.employee_id) FILTER (WHERE e.termination_date BETWEEN m.month_start AND m.month_end) AS separations
    FROM reporting_months AS m
    CROSS JOIN (SELECT DISTINCT employment_type FROM employees) AS t
    LEFT JOIN employees AS e ON e.employment_type = t.employment_type
    WHERE m.month_start >= DATE_TRUNC('year', as_of_date()) - INTERVAL 2 YEAR
    GROUP BY m.month_start, t.employment_type
)
SELECT
    employment_type,
    ROUND(AVG(closing_headcount), 1) AS average_month_end_headcount,
    SUM(separations) AS separations,
    ROUND(100.0 * SUM(separations) / AVG(closing_headcount) / COUNT(DISTINCT YEAR(month_start)), 1)
        AS annualized_turnover_pct
FROM monthly
GROUP BY employment_type
ORDER BY annualized_turnover_pct DESC;

CREATE OR REPLACE VIEW hires_vs_terminations_by_year AS
WITH hires AS (
    SELECT YEAR(hire_date) AS calendar_year, COUNT(*) AS hires
    FROM employees
    GROUP BY YEAR(hire_date)
),
terminations AS (
    SELECT YEAR(termination_date) AS calendar_year, COUNT(*) AS terminations
    FROM employees
    WHERE termination_date IS NOT NULL
    GROUP BY YEAR(termination_date)
)
SELECT
    h.calendar_year,
    h.hires,
    COALESCE(t.terminations, 0) AS terminations,
    h.hires - COALESCE(t.terminations, 0) AS net_change,
    ROUND(h.hires / NULLIF(t.terminations, 0), 2) AS hires_per_termination,
    SUM(h.hires - COALESCE(t.terminations, 0)) OVER (ORDER BY h.calendar_year) AS cumulative_net_change
FROM hires AS h
LEFT JOIN terminations AS t USING (calendar_year)
ORDER BY h.calendar_year;

CREATE OR REPLACE VIEW separations_by_tenure_at_exit AS
SELECT
    CASE
        WHEN DATEDIFF('day', hire_date, termination_date) < 90 THEN '1. Under 90 days'
        WHEN DATEDIFF('day', hire_date, termination_date) < 365 THEN '2. 90 days to 1 year'
        WHEN DATEDIFF('day', hire_date, termination_date) < 1095 THEN '3. 1 to 3 years'
        ELSE '4. 3 years or more'
    END AS tenure_at_exit,
    COUNT(*) AS separations,
    COUNT(*) FILTER (WHERE termination_type = 'Voluntary') AS voluntary,
    COUNT(*) FILTER (WHERE termination_type = 'Involuntary') AS involuntary,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_separations_pct
FROM employees
WHERE termination_date IS NOT NULL
GROUP BY tenure_at_exit
ORDER BY tenure_at_exit;
