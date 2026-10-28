import argparse
import csv
import math
import random
from datetime import date, timedelta
from pathlib import Path

SEED = 20240101
START_DATE = date(2016, 1, 1)
AS_OF_DATE = date(2025, 12, 31)
DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent.parent / "data" / "sample"

DEPARTMENTS = [
    (1, "Engineering", 0.24, 0.12),
    (2, "Sales", 0.18, 0.22),
    (3, "Customer Support", 0.17, 0.25),
    (4, "Marketing", 0.08, 0.15),
    (5, "Finance", 0.07, 0.10),
    (6, "Human Resources", 0.05, 0.13),
    (7, "Operations", 0.13, 0.18),
    (8, "Product", 0.08, 0.11),
]

JOBS = [
    (101, "Software Engineer I", 1, 1, 70000, 95000, 0.30),
    (102, "Software Engineer II", 1, 2, 90000, 120000, 0.30),
    (103, "Senior Software Engineer", 1, 3, 115000, 155000, 0.20),
    (104, "QA Engineer", 1, 2, 65000, 90000, 0.12),
    (105, "Engineering Manager", 1, 4, 145000, 185000, 0.08),
    (201, "Sales Development Representative", 2, 1, 45000, 60000, 0.40),
    (202, "Account Executive", 2, 2, 60000, 90000, 0.32),
    (203, "Senior Account Executive", 2, 3, 85000, 120000, 0.18),
    (204, "Sales Manager", 2, 4, 110000, 150000, 0.10),
    (301, "Support Specialist", 3, 1, 38000, 50000, 0.55),
    (302, "Senior Support Specialist", 3, 2, 48000, 62000, 0.25),
    (303, "Support Team Lead", 3, 3, 60000, 78000, 0.13),
    (304, "Support Manager", 3, 4, 75000, 100000, 0.07),
    (401, "Marketing Coordinator", 4, 1, 45000, 60000, 0.35),
    (402, "Marketing Specialist", 4, 2, 58000, 78000, 0.30),
    (403, "Content Strategist", 4, 2, 55000, 75000, 0.23),
    (404, "Senior Marketing Manager", 4, 4, 100000, 135000, 0.12),
    (501, "Accountant", 5, 2, 58000, 78000, 0.35),
    (502, "Financial Analyst", 5, 2, 65000, 85000, 0.30),
    (503, "Senior Financial Analyst", 5, 3, 80000, 105000, 0.23),
    (504, "Finance Manager", 5, 4, 110000, 145000, 0.12),
    (601, "HR Coordinator", 6, 1, 45000, 58000, 0.35),
    (602, "Recruiter", 6, 2, 55000, 75000, 0.33),
    (603, "HR Business Partner", 6, 3, 75000, 100000, 0.20),
    (604, "HR Manager", 6, 4, 95000, 125000, 0.12),
    (701, "Operations Associate", 7, 1, 40000, 55000, 0.45),
    (702, "Logistics Coordinator", 7, 2, 48000, 65000, 0.25),
    (703, "Operations Analyst", 7, 2, 55000, 75000, 0.20),
    (704, "Operations Manager", 7, 4, 90000, 120000, 0.10),
    (801, "Product Analyst", 8, 2, 70000, 92000, 0.30),
    (802, "UX Designer", 8, 2, 75000, 100000, 0.27),
    (803, "Product Manager", 8, 3, 105000, 140000, 0.28),
    (804, "Senior Product Manager", 8, 4, 130000, 170000, 0.15),
]

LOCATIONS = [
    (1, "Austin", "United States", "North America", 0.30),
    (2, "New York", "United States", "North America", 0.22),
    (3, "Toronto", "Canada", "North America", 0.14),
    (4, "London", "United Kingdom", "Europe", 0.14),
    (5, "Berlin", "Germany", "Europe", 0.08),
    (6, "Remote", "United States", "Remote", 0.12),
]

EMPLOYMENT_TYPES = [("Full-time", 0.82, 1.0), ("Part-time", 0.08, 1.4), ("Contract", 0.10, 1.8)]
MONTHLY_SEASONALITY = [1.3, 1.2, 1.15, 1.0, 0.95, 0.9, 0.85, 0.9, 1.2, 1.05, 0.9, 0.6]


def next_month(month_start):
    return date(month_start.year + month_start.month // 12, month_start.month % 12 + 1, 1)


def month_starts(start, end):
    current = date(start.year, start.month, 1)
    while current <= end:
        yield current
        current = next_month(current)


def monthly_hire_volume(rng, month_start):
    years_elapsed = (month_start.year - START_DATE.year) + (month_start.month - 1) / 12
    expected = (6.5 + 0.75 * years_elapsed) * MONTHLY_SEASONALITY[month_start.month - 1]
    return max(0, round(rng.gauss(expected, math.sqrt(expected))))


def weighted_choice(rng, items, weight_index):
    return rng.choices(items, weights=[item[weight_index] for item in items], k=1)[0]


def build_employees(rng):
    employees = []
    for month_start in month_starts(START_DATE, AS_OF_DATE):
        month_length = (next_month(month_start) - month_start).days
        for _ in range(monthly_hire_volume(rng, month_start)):
            department = weighted_choice(rng, DEPARTMENTS, 2)
            department_jobs = [job for job in JOBS if job[2] == department[0]]
            job = weighted_choice(rng, department_jobs, 6)
            location = weighted_choice(rng, LOCATIONS, 4)
            employment_type = weighted_choice(rng, EMPLOYMENT_TYPES, 1)
            hire_date = month_start + timedelta(days=rng.randrange(month_length))

            annual_attrition = min(0.9, department[3] * employment_type[2])
            daily_hazard = -math.log(1 - annual_attrition) / 365.25
            days_employed = max(1, int(-math.log(1 - rng.random()) / daily_hazard))
            termination_date = hire_date + timedelta(days=days_employed)

            if termination_date <= AS_OF_DATE:
                status = "Terminated"
                termination_type = "Voluntary" if rng.random() < 0.74 else "Involuntary"
            else:
                status = "Active"
                termination_date = None
                termination_type = None

            salary_position = rng.betavariate(2.2, 2.2)
            salary = round((job[4] + (job[5] - job[4]) * salary_position) / 100) * 100

            employees.append(
                {
                    "job_id": job[0],
                    "location_id": location[0],
                    "employment_type": employment_type[0],
                    "hire_date": hire_date,
                    "termination_date": termination_date,
                    "employment_status": status,
                    "termination_type": termination_type,
                    "annual_salary": salary,
                }
            )

    employees.sort(key=lambda row: (row["hire_date"], row["job_id"], row["annual_salary"]))
    for employee_id, row in enumerate(employees, start=10001):
        row["employee_id"] = employee_id
    return employees


def write_csv(path, header, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def format_date(value):
    return value.isoformat() if value else ""


def generate(output_dir, seed=SEED):
    output_dir.mkdir(parents=True, exist_ok=True)
    employees = build_employees(random.Random(seed))

    write_csv(
        output_dir / "departments.csv",
        ["department_id", "department_name"],
        [row[:2] for row in DEPARTMENTS],
    )
    write_csv(
        output_dir / "jobs.csv",
        ["job_id", "job_title", "department_id", "job_level", "salary_band_min", "salary_band_max"],
        [row[:6] for row in JOBS],
    )
    write_csv(
        output_dir / "locations.csv",
        ["location_id", "location_name", "country", "region"],
        [row[:4] for row in LOCATIONS],
    )
    write_csv(
        output_dir / "employees.csv",
        [
            "employee_id",
            "job_id",
            "location_id",
            "employment_type",
            "hire_date",
            "termination_date",
            "employment_status",
            "termination_type",
            "annual_salary",
        ],
        [
            (
                row["employee_id"],
                row["job_id"],
                row["location_id"],
                row["employment_type"],
                format_date(row["hire_date"]),
                format_date(row["termination_date"]),
                row["employment_status"],
                row["termination_type"] or "",
                row["annual_salary"],
            )
            for row in employees
        ],
    )
    return len(employees)


def main():
    parser = argparse.ArgumentParser(description="Generate the synthetic workforce sample dataset.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--seed", type=int, default=SEED)
    args = parser.parse_args()
    generate(args.output_dir, args.seed)


if __name__ == "__main__":
    main()
