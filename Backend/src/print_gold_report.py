import json
import os

def main():
    json_path = 'transactions_to_import.json'
    if not os.path.exists(json_path):
        print(f"Error: {json_path} does not exist.")
        return

    with open(json_path, 'r', encoding='utf-8') as f:
        txs = json.load(f)

    # Filter for gold transactions
    gold_txs = [t for t in txs if t['metalType'] == 'gold']
    
    print(f"Found {len(gold_txs)} gold transactions.")

    running_total = 0.0
    rows = []

    # Write output to a Markdown file so the user can easily view the entire list
    markdown_lines = [
        "# Swastik Jewels Gold Running Balance Report",
        "",
        "This report shows the chronological running balance of the shop's gold vault stock, starting with the opening balance of **792.56g**.",
        "",
        "| Row | Date | Customer Name | In (g) | Out (g) | Running Total (g) | Notes |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"
    ]

    for idx, t in enumerate(gold_txs):
        date_formatted = t['date'][:10] # YYYY-MM-DD
        is_in = t['type'] == 'metalIn'
        weight = t['metalWeight']
        
        # Format date for display (DD/MM/YYYY)
        y, m, d = date_formatted.split('-')
        display_date = f"{d}/{m}/{y}"

        if idx == 0:
            # First transaction is the opening balance of 792.56
            running_total = weight
            rows.append({
                'row': 1,
                'date': display_date,
                'party': t['partyName'],
                'in': weight,
                'out': 0.0,
                'total': running_total,
                'note': 'OPENING BALANCE'
            })
        else:
            if is_in:
                running_total += weight
                rows.append({
                    'row': idx + 1,
                    'date': display_date,
                    'party': t['partyName'],
                    'in': weight,
                    'out': 0.0,
                    'total': running_total,
                    'note': t['notes']
                })
            else:
                running_total -= weight
                rows.append({
                    'row': idx + 1,
                    'date': display_date,
                    'party': t['partyName'],
                    'in': 0.0,
                    'out': weight,
                    'total': running_total,
                    'note': t['notes']
                })

    for r in rows:
        in_str = f"{r['in']:.2f}" if r['in'] > 0 else "-"
        out_str = f"{r['out']:.2f}" if r['out'] > 0 else "-"
        markdown_lines.append(
            f"| {r['row']} | {r['date']} | {r['party']} | {in_str} | {out_str} | {r['total']:.2f} | {r['note']} |"
        )

    # Save report
    report_path = 'gold_running_balance_report.md'
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(markdown_lines))

    print(f"Report saved to {report_path}")

if __name__ == '__main__':
    main()
