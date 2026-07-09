import sqlite3
import datetime

def add_months(d, months):
    new_month = d.month - 1 + months
    new_year = d.year + (new_month // 12)
    new_month = (new_month % 12) + 1
    days_in_month = [31, 29 if new_year % 4 == 0 and (new_year % 100 != 0 or new_year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][new_month-1]
    new_day = min(d.day, days_in_month)
    return datetime.datetime(new_year, new_month, new_day, d.hour, d.minute, d.second)

def simulate():
    db_path = "/Users/jottache/Library/Developer/CoreSimulator/Devices/D4691B7A-ED41-47E5-BE0C-0ECE81EF4BD5/data/Containers/Data/Application/974A3DF3-0925-46E9-ACEB-0543F08DE0E7/Documents/quebrado.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Load rates
    cursor.execute("SELECT value FROM settings WHERE key='bcvRate'")
    bcv_rate = float(cursor.fetchone()[0])
    print(f"Rates: BCV={bcv_rate}")

    # Load accounts
    cursor.execute("SELECT id, name, currency, balance FROM accounts")
    accounts = []
    projected_balances = {}
    for r in cursor.fetchall():
        acc = {"id": r[0], "name": r[1], "currency": r[2], "balance": r[3]}
        accounts.append(acc)
        projected_balances[r[0]] = r[3]
    
    print("Accounts:")
    for acc in accounts:
        print(f"  {acc['name']} ({acc['currency']}): {acc['balance']}")

    # Load pockets
    cursor.execute("SELECT id, name, current_amount_usd, target_amount_usd, target_date FROM pockets")
    pockets = []
    projected_pocket_balances = {}
    for r in cursor.fetchall():
        p = {"id": r[0], "name": r[1], "current_amount_usd": r[2], "target_amount_usd": r[3], "target_date": r[4]}
        pockets.append(p)
        projected_pocket_balances[r[0]] = r[2]

    print("Pockets:")
    for p in pockets:
        print(f"  {p['name']}: current={p['current_amount_usd']}, target={p['target_amount_usd']}")

    # Load recurring payments
    cursor.execute("SELECT id, name, amount, currency, frequency, start_date, type, account_id, pocket_id, total_installments, custom_days, is_variable, max_amount FROM recurring_payments")
    recurring_payments = []
    for r in cursor.fetchall():
        payment = {
            "id": r[0],
            "name": r[1],
            "amount": r[2],
            "currency": r[3],
            "frequency": r[4],
            "start_date": r[5],
            "type": r[6],
            "account_id": r[7],
            "pocket_id": r[8],
            "total_installments": r[9],
            "custom_days": r[10],
            "is_variable": r[11],
            "max_amount": r[12]
        }
        recurring_payments.append(payment)

    range_start = datetime.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    range_end = range_start + datetime.timedelta(days=365)
    filter_end = range_start + datetime.timedelta(days=30) # Show 30 days horizon

    occurrences = []
    
    for payment in recurring_payments:
        # Parse ISO start date
        try:
            start_date_str = payment["start_date"].split(".")[0]
            start_date = datetime.datetime.strptime(start_date_str, "%Y-%m-%dT%H:%M:%S")
        except Exception:
            start_date_str = payment["start_date"]
            if "T" in start_date_str:
                start_date_str = start_date_str.split("T")[0]
            start_date = datetime.datetime.strptime(start_date_str, "%Y-%m-%d")

        start_date = start_date.replace(hour=0, minute=0, second=0, microsecond=0)
        current = start_date
        count = 0

        while current <= range_end:
            count += 1
            if payment["total_installments"] is not None and count > payment["total_installments"]:
                break
            
            is_overdue = current < range_start
            
            occurrences.append({
                "payment": payment,
                "date": current,
                "installment_number": count if payment["total_installments"] is not None else None,
                "is_overdue": is_overdue
            })

            # Advance by frequency
            freq = payment["frequency"]
            if freq == "weekly":
                current += datetime.timedelta(days=7)
            elif freq == "biweekly":
                current += datetime.timedelta(days=14)
            elif freq == "fifteenDays":
                current += datetime.timedelta(days=15)
            elif freq == "monthly":
                current = add_months(current, 1)
            elif freq == "threeMonths":
                current = add_months(current, 3)
            elif freq == "yearly":
                current = add_months(current, 12)
            elif freq == "custom":
                days = payment["custom_days"] or 30
                current += datetime.timedelta(days=days)
            else:
                current += datetime.timedelta(days=30)

    # Sort occurrences chronologically
    occurrences.sort(key=lambda x: x["date"])

    # First Pass: find pocket deficits and generate virtual deposits
    temp_pocket_balances = {p["id"]: p["current_amount_usd"] for p in pockets}
    consolidated_deposits = {}

    for occ in occurrences:
        payment = occ["payment"]
        p_id = payment["pocket_id"]
        if p_id:
            amount_usd = payment["amount"]
            if payment["currency"] == "bsBCV":
                amount_usd = amount_usd / bcv_rate if bcv_rate > 0 else 0.0
            
            if payment["type"] == "income":
                temp_pocket_balances[p_id] = temp_pocket_balances.get(p_id, 0.0) + amount_usd
            else:
                cur_pocket_bal = temp_pocket_balances.get(p_id, 0.0)
                if cur_pocket_bal < amount_usd:
                    deficit = amount_usd - cur_pocket_bal
                    
                    # Find most recent income event before occurrence date, or today
                    deposit_date = range_start
                    for other in occurrences:
                        if other["payment"]["type"] == "income" and other["date"] < occ["date"]:
                            if other["date"] > deposit_date:
                                deposit_date = other["date"]

                    date_key = f"{deposit_date.strftime('%Y-%m-%d')}_{p_id}"
                    
                    if date_key in consolidated_deposits:
                        existing = consolidated_deposits[date_key]
                        updated_title = existing["target_expense_title"]
                        if payment["name"] not in updated_title:
                            parts = updated_title.split(", ")
                            if len(parts) >= 2:
                                if "otros" not in updated_title:
                                    updated_title = f"{parts[0]}, {parts[1]} y otros"
                            else:
                                updated_title = f"{updated_title}, {payment['name']}"
                        
                        consolidated_deposits[date_key] = {
                            "pocket_id": p_id,
                            "amount_usd": existing["amount_usd"] + deficit,
                            "amount": existing["amount"] + (deficit if payment["currency"] == "usd" else deficit * bcv_rate),
                            "currency": payment["currency"],
                            "date": deposit_date,
                            "target_expense_title": updated_title
                        }
                    else:
                        consolidated_deposits[date_key] = {
                            "pocket_id": p_id,
                            "amount_usd": deficit,
                            "amount": deficit if payment["currency"] == "usd" else deficit * bcv_rate,
                            "currency": payment["currency"],
                            "date": deposit_date,
                            "target_expense_title": payment["name"]
                        }
                    temp_pocket_balances[p_id] = cur_pocket_bal + deficit
                
                temp_pocket_balances[p_id] -= amount_usd
                if temp_pocket_balances[p_id] < 0:
                    temp_pocket_balances[p_id] = 0.0

    # Merge
    sim_events = []
    for occ in occurrences:
        sim_events.append({"date": occ["date"], "occurrence": occ, "deposit": None})
    for dep in consolidated_deposits.values():
        sim_events.append({"date": dep["date"], "occurrence": None, "deposit": dep})

    # Sort
    def sort_weight(e):
        if e["occurrence"]:
            return 1 if e["occurrence"]["payment"]["type"] == "income" else 3
        return 2

    sim_events.sort(key=lambda x: (x["date"], sort_weight(x)))

    print("\n--- TIMELINE SIMULATION (30 DAYS horizon) ---")
    
    total_usd = 0.0
    for acc in accounts:
        if acc["currency"] == "usd":
            total_usd += acc["balance"]
        else:
            total_usd += acc["balance"] / bcv_rate if bcv_rate > 0 else 0.0

    print(f"Initial Total USD: {total_usd:.2f}")

    for e in sim_events:
        if e["date"] > filter_end:
            continue
            
        date_str = e["date"].strftime("%Y-%m-%d")
        
        if e["deposit"]:
            dep = e["deposit"]
            p_name = next(p["name"] for p in pockets if p["id"] == dep["pocket_id"])
            projected_pocket_balances[dep["pocket_id"]] += dep["amount_usd"]
            
            # Recalculate balances
            total_usd_val = 0.0
            for acc_id, bal in projected_balances.items():
                acc_curr = next(a["currency"] for a in accounts if a["id"] == acc_id)
                if acc_curr == "usd":
                    total_usd_val += bal
                else:
                    total_usd_val += bal / bcv_rate if bcv_rate > 0 else 0.0
            total_pockets = sum(projected_pocket_balances.values())
            proj_liquid = total_usd_val - total_pockets

            print(f"[{date_str}] SUGERENCIA: Aprovisionar Bolsillo '{p_name}' con {dep['currency']} {dep['amount']:.2f} (para {dep['target_expense_title']})")
            print(f"             -> Total USD: {total_usd_val:.2f} | Liquid: {proj_liquid:.2f}")
            
        else:
            occ = e["occurrence"]
            payment = occ["payment"]
            acc_id = payment["account_id"] or ("default_usd" if payment["currency"] == "usd" else "default_ves")
            acc_name = next(a["name"] for a in accounts if a["id"] == acc_id)
            acc_curr = next(a["currency"] for a in accounts if a["id"] == acc_id)
            
            amount_acc = payment["amount"]
            if payment["currency"] != acc_curr:
                if payment["currency"] == "usd":
                    amount_acc = payment["amount"] * bcv_rate
                else:
                    amount_acc = payment["amount"] / bcv_rate if bcv_rate > 0 else 0.0
            
            amount_usd = payment["amount"]
            if payment["currency"] == "bsBCV":
                amount_usd = payment["amount"] / bcv_rate if bcv_rate > 0 else 0.0

            # Apply
            if payment["type"] == "income":
                projected_balances[acc_id] += amount_acc
                if payment["pocket_id"]:
                    projected_pocket_balances[payment["pocket_id"]] += amount_usd
            else:
                projected_balances[acc_id] -= amount_acc
                if payment["pocket_id"]:
                    projected_pocket_balances[payment["pocket_id"]] = max(0.0, projected_pocket_balances[payment["pocket_id"]] - amount_usd)
            
            # Recalculate
            total_usd_val = 0.0
            for acc_id_t, bal in projected_balances.items():
                acc_curr_t = next(a["currency"] for a in accounts if a["id"] == acc_id_t)
                if acc_curr_t == "usd":
                    total_usd_val += bal
                else:
                    total_usd_val += bal / bcv_rate if bcv_rate > 0 else 0.0
            total_pockets = sum(projected_pocket_balances.values())
            proj_liquid = total_usd_val - total_pockets
            
            label_inst = f" (Cuota {occ['installment_number']}/{payment['total_installments']})" if occ["installment_number"] else ""
            type_sign = "+" if payment["type"] == "income" else "-"
            print(f"[{date_str}] EVENTO: {payment['type'].upper()} '{payment['name']}'{label_inst} de {payment['currency']} {payment['amount']:.2f} en '{acc_name}'")
            print(f"             -> Total USD: {total_usd_val:.2f} | Liquid: {proj_liquid:.2f}")

if __name__ == "__main__":
    simulate()
