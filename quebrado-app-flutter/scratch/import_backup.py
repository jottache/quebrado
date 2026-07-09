import json
import sqlite3
import os

db_path = "/Users/jottache/Library/Developer/CoreSimulator/Devices/D4691B7A-ED41-47E5-BE0C-0ECE81EF4BD5/data/Containers/Data/Application/5F6FA6A3-DC8F-4236-B87F-805FF2726375/Documents/quebrado.db"
json_path = "/Users/jottache/Downloads/copia_seguridad_quebrado_1782504261161.json"

if not os.path.exists(db_path):
    print(f"Error: Database not found at {db_path}")
    exit(1)

if not os.path.exists(json_path):
    print(f"Error: JSON file not found at {json_path}")
    exit(1)

with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

tables = [
    'settings',
    'categories',
    'accounts',
    'pockets',
    'transactions',
    'rate_history',
    'recurring_payments',
    'recurring_payment_confirmations',
    'recurring_payment_partials'
]

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    cursor.execute("PRAGMA foreign_keys = OFF")
    
    # Clean tables
    for table in tables:
        cursor.execute(f"DELETE FROM {table}")
        print(f"Cleared table: {table}")
        
    # Insert rows
    for table in tables:
        rows = data.get(table, [])
        if not rows:
            print(f"No rows to insert for table: {table}")
            continue
            
        inserted_count = 0
        for row in rows:
            # Construct insert query
            columns = list(row.keys())
            placeholders = ", ".join(["?" for _ in columns])
            sql = f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({placeholders})"
            values = [row[col] for col in columns]
            
            cursor.execute(sql, values)
            inserted_count += 1
            
        print(f"Inserted {inserted_count} rows into {table}")
        
    conn.commit()
    print("Database updated successfully!")
    
except Exception as e:
    conn.rollback()
    print(f"Error during import: {e}")
    exit(1)
finally:
    conn.close()
