import json
import pandas as pd
import os

def parse_date(date_val):
    if pd.isna(date_val):
        return None
        
    # If it is a string
    if isinstance(date_val, str):
        date_val = date_val.strip()
        if '30/02/2026' in date_val:
            return "2007-04-30T00:00:00.000Z"
        # Split by '/'
        parts = date_val.split('/')
        if len(parts) == 3:
            d = int(parts[0])
            m = int(parts[1])
            y = 2007 # Normalize year to 2007
            return f"{y:04d}-{m:02d}-{d:02d}T00:00:00.000Z"
            
    # Try parsing as timestamp
    try:
        t = pd.Timestamp(date_val)
        if pd.isna(t):
            return None
            
        y = 2007 # Normalize year to 2007
        
        # Swapping logic for Excel MM/DD swap
        # Excel parsed DD/MM as MM/DD, so the parsed t.day is the actual month (4 or 5)
        # and t.month is the actual day.
        if t.day in [4, 5]:
            m = t.day
            d = t.month
        else:
            m = t.month
            d = t.day
            
        return f"{y:04d}-{m:02d}-{d:02d}T00:00:00.000Z"
    except Exception as e:
        print(f"Error parsing date {date_val}: {e}")
        return None

def clean_float(val):
    if pd.isna(val):
        return 0.0
    if isinstance(val, (int, float)):
        return float(val)
    s = str(val).strip().lower()
    for suffix in ["ct", "carats", "carat", "g", "gm", "grams", "gram"]:
        if s.endswith(suffix):
            s = s[:-len(suffix)].strip()
            break
    try:
        return float(s)
    except ValueError:
        return 0.0

def main():
    excel_path = '../customers_data.xlsx'
    df = pd.read_excel(excel_path)
    
    # Drop rows where Party is empty
    df = df.dropna(subset=['Party'])
    
    transactions = []
    
    for idx, row in df.iterrows():
        sr_no = row.get('Sr. No.')
        date_raw = row.get('Date')
        party_raw = str(row.get('Party')).strip()
        particulars = str(row.get('Particulars/ Details')).strip() if pd.notna(row.get('Particulars/ Details')) else ""
        item_raw = str(row.get('Item')).strip().upper()
        out_val = row.get('Out')
        in_val = row.get('In')
        
        # Name overrides
        if party_raw == "KIRSHAN UNCLE":
            party_name = "KRISHAN UNCLE"
        elif party_raw == "onkar jew rohini":
            party_name = "omkar jew rohini"
        elif party_raw == "OPENING":
            party_name = "swastik jewels"
        else:
            party_name = party_raw
            
        date_iso = parse_date(date_raw)
        if not date_iso:
            print(f"Warning: Row index {idx} has invalid date '{date_raw}'. Skipping.")
            continue
            
        # Determine values
        clean_in = clean_float(in_val)
        clean_out = clean_float(out_val)
        
        has_in = clean_in > 0
        has_out = clean_out > 0
        
        if not has_in and not has_out:
            print(f"Warning: Row index {idx} has no In or Out value. Skipping.")
            continue
            
        # Helper function to build transaction object
        def build_txn(val, direction):
            # direction is either "In" or "Out"
            txn = {
                "srNo": sr_no if pd.notna(sr_no) else None,
                "excelRowIndex": idx,
                "partyName": party_name,
                "notes": particulars,
                "date": date_iso,
                "cashAmount": 0,
                "metalWeight": 0,
                "metalType": "",
                "metalPurity": "",
                "paymentMode": "cash",
                "type": "receipt"
            }
            
            if item_raw == 'C': # Cash
                txn["cashAmount"] = val
                txn["paymentMode"] = "cash"
                txn["type"] = "receipt" if direction == "In" else "payment"
            elif item_raw == 'O': # Online/UPI
                txn["cashAmount"] = val
                txn["paymentMode"] = "upi"
                txn["type"] = "receipt" if direction == "In" else "payment"
            elif item_raw == 'M': # Metal (Gold)
                txn["metalWeight"] = val
                txn["metalType"] = "gold"
                txn["metalPurity"] = "100 %"
                txn["paymentMode"] = "metal"
                txn["type"] = "metalIn" if direction == "In" else "metalOut"
            elif item_raw == 'D': # Diamond
                txn["metalWeight"] = val
                txn["metalType"] = "diamond"
                txn["metalPurity"] = ""
                txn["paymentMode"] = "metal"
                txn["type"] = "metalIn" if direction == "In" else "metalOut"
            else:
                print(f"Warning: Unknown Item type '{item_raw}' at row {idx}")
                return None
                
            return txn

        # Handle split transactions if row has both In and Out
        if has_in and has_out:
            # Generate Out transaction first, then In transaction (both same date)
            t_out = build_txn(clean_out, "Out")
            t_in = build_txn(clean_in, "In")
            if t_out:
                transactions.append(t_out)
            if t_in:
                transactions.append(t_in)
        elif has_in:
            t_in = build_txn(clean_in, "In")
            if t_in:
                transactions.append(t_in)
        elif has_out:
            t_out = build_txn(clean_out, "Out")
            if t_out:
                transactions.append(t_out)

    # Sort transactions chronologically by parsed date
    # We sort by date string first, then maintain original Excel row index order for tie-breaking
    transactions.sort(key=lambda x: (x['date'], x['excelRowIndex']))
    
    # Assign sequential times starting at 12:00:00 for transactions on the same date
    date_counters = {}
    for txn in transactions:
        date_str = txn['date'][:10] # Extract "YYYY-MM-DD"
        if date_str not in date_counters:
            date_counters[date_str] = 0
        minute = date_counters[date_str]
        date_counters[date_str] += 1
        
        hour = 12 + (minute // 60)
        min_part = minute % 60
        txn['date'] = f"{date_str}T{hour:02d}:{min_part:02d}:00.000Z"
        
    # Save output to JSON
    output_path = 'transactions_to_import.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(transactions, f, indent=2)
        
    print(f"Parsed {len(transactions)} transaction entries from Excel with sequential timestamps.")
    print(f"Saved parsed transactions to {output_path}")

if __name__ == '__main__':
    main()
