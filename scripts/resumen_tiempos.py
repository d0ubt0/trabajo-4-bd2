#!/usr/bin/env python3
import os
import re

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORACLE_DIR = os.path.join(ROOT_DIR, "report", "resultados", "oracle")
POSTGRES_DIR = os.path.join(ROOT_DIR, "report", "resultados", "postgres")

def oracle_elapsed_to_ms(elapsed_str):
    if not elapsed_str or elapsed_str == "N/A":
        return None
    parts = elapsed_str.split(':')
    if len(parts) == 3:
        try:
            h, m, s = int(parts[0]), int(parts[1]), float(parts[2])
            total_sec = h * 3600 + m * 60 + s
            return round(total_sec * 1000, 2)
        except ValueError:
            return None
    return None

def postgres_time_to_ms(time_str):
    if not time_str or time_str == "N/A":
        return None
    match = re.search(r"([\d\.]+)", time_str)
    if match:
        try:
            return round(float(match.group(1)), 2)
        except ValueError:
            return None
    return None

def format_ms(ms_val):
    if ms_val is None:
        return "N/A"
    if ms_val >= 1000:
        return f"{ms_val:,.2f} ms ({ms_val/1000:.2f} s)"
    return f"{ms_val:,.2f} ms"

def parse_oracle_carga(filepath):
    if not os.path.exists(filepath):
        return None
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    match = re.search(r"Call completed\.\s*Elapsed:\s*([\d:\.]+)", content)
    if match:
        return oracle_elapsed_to_ms(match.group(1))
    return None

def parse_postgres_carga(filepath):
    if not os.path.exists(filepath):
        return None
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    match = re.search(r"CALL\s+Time:\s*([\d\.]+\s*ms)", content)
    if match:
        return postgres_time_to_ms(match.group(1))
    return None

def parse_oracle_consultas(filepath):
    times = {}
    if not os.path.exists(filepath):
        return times
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    current_q = None
    for line in lines:
        if "Consulta 1:" in line:
            current_q = "Q1 (NOT EXISTS)"
        elif "Consulta 2:" in line:
            current_q = "Q2 (LISTAGG)"
        elif "Consulta 3:" in line:
            current_q = "Q3 (COUNTS)"
        elif "Consulta 4:" in line:
            current_q = "Q4 (MINUS)"
        elif "Elapsed:" in line and current_q:
            match = re.search(r"Elapsed:\s*([\d:\.]+)", line)
            if match:
                times[current_q] = oracle_elapsed_to_ms(match.group(1))
                current_q = None
    return times

def parse_postgres_consultas(filepath):
    times = {}
    if not os.path.exists(filepath):
        return times
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    current_q = None
    for line in lines:
        if "Consulta 1:" in line:
            current_q = "Q1 (NOT EXISTS)"
        elif "Consulta 2:" in line:
            current_q = "Q2 (STRING_AGG)"
        elif "Consulta 3:" in line:
            current_q = "Q3 (COUNTS)"
        elif "Consulta 4:" in line:
            current_q = "Q4 (EXCEPT)"
        elif line.startswith("Time:") and current_q:
            match = re.search(r"Time:\s*([\d\.]+\s*ms)", line)
            if match:
                times[current_q] = postgres_time_to_ms(match.group(1))
                current_q = None
    return times

def print_summary():
    samples = [
        ("100prov_1000rel", "100 prov / 1.000 rel"),
        ("500prov_5000rel", "500 prov / 5.000 rel"),
        ("1000prov_10000rel", "1.000 prov / 10.000 rel"),
        ("2000prov_25000rel", "2.000 prov / 25.000 rel"),
        ("5000prov_50000rel", "5.000 prov / 50.000 rel"),
    ]

    print("\n" + "="*95)
    print(f"{'RESUMEN COMPARATIVO DE TIEMPOS DE EJECUCIÓN (NORMALIZADO A MS / SEG)':^95}")
    print("="*95)

    queries = ["Q1 (NOT EXISTS)", "Q2 (STRING_AGG/LISTAGG)", "Q3 (COUNTS)", "Q4 (EXCEPT/MINUS)"]

    for sample_key, sample_label in samples:
        print(f"\n Muestra: {sample_label} ({sample_key})")
        print("-" * 95)
        print(f"{'Operación / Consulta':<30} | {'Oracle 23c (ms / s)':<30} | {'PostgreSQL 16 (ms / s)':<30}")
        print("-" * 95)

        ora_carga_file = os.path.join(ORACLE_DIR, f"{sample_key}_carga.txt")
        pg_carga_file = os.path.join(POSTGRES_DIR, f"{sample_key}_carga.txt")
        ora_carga_ms = parse_oracle_carga(ora_carga_file)
        pg_carga_ms = parse_postgres_carga(pg_carga_file)
        print(f"{'Carga de Datos (Procedure)':<30} | {format_ms(ora_carga_ms):<30} | {format_ms(pg_carga_ms):<30}")

        ora_cons_file = os.path.join(ORACLE_DIR, f"{sample_key}_consultas.txt")
        pg_cons_file = os.path.join(POSTGRES_DIR, f"{sample_key}_consultas.txt")
        ora_times = parse_oracle_consultas(ora_cons_file)
        pg_times = parse_postgres_consultas(pg_cons_file)

        q_map_ora = {"Q1 (NOT EXISTS)": "Q1 (NOT EXISTS)", "Q2 (STRING_AGG/LISTAGG)": "Q2 (LISTAGG)", "Q3 (COUNTS)": "Q3 (COUNTS)", "Q4 (EXCEPT/MINUS)": "Q4 (MINUS)"}
        q_map_pg = {"Q1 (NOT EXISTS)": "Q1 (NOT EXISTS)", "Q2 (STRING_AGG/LISTAGG)": "Q2 (STRING_AGG)", "Q3 (COUNTS)": "Q3 (COUNTS)", "Q4 (EXCEPT/MINUS)": "Q4 (EXCEPT)"}

        for q_label in queries:
            ora_ms = ora_times.get(q_map_ora[q_label])
            pg_ms = pg_times.get(q_map_pg[q_label])
            print(f"{q_label:<30} | {format_ms(ora_ms):<30} | {format_ms(pg_ms):<30}")
        print("-" * 95)

    print("="*95 + "\n")

if __name__ == "__main__":
    print_summary()
