import json
import pandas as pd
import difflib
import os

def main():
    # Load DB parties
    db_path = os.path.join(os.path.dirname(__file__), 'parties.json')
    with open(db_path, 'r', encoding='utf-8') as f:
        db_parties = json.load(f)
    
    db_names = {p['name'].strip(): p for p in db_parties}
    db_names_lower = {name.lower(): name for name in db_names}

    # Load Excel parties
    df = pd.read_excel('../customers_data.xlsx')
    excel_names = sorted(df['Party'].dropna().unique())

    exact_matches = []
    case_insensitive_matches = []
    unmatched = []

    for name in excel_names:
        name_clean = str(name).strip()
        if name_clean in db_names:
            exact_matches.append(name_clean)
        elif name_clean.lower() in db_names_lower:
            db_match = db_names_lower[name_clean.lower()]
            case_insensitive_matches.append((name_clean, db_match))
        else:
            # Suggest closest match
            matches = difflib.get_close_matches(name_clean, list(db_names.keys()), n=1, cutoff=0.6)
            suggestion = matches[0] if matches else "None"
            unmatched.append((name_clean, suggestion))

    print(f"Total Unique Parties in Excel: {len(excel_names)}")
    print(f"Exact Matches: {len(exact_matches)}")
    print(f"Case-insensitive/Whitespace Matches: {len(case_insensitive_matches)}")
    print(f"Unmatched: {len(unmatched)}")
    
    report = {
        "exact_matches_count": len(exact_matches),
        "case_insensitive_matches": [{"excel": item[0], "db": item[1]} for item in case_insensitive_matches],
        "unmatched": [{"excel": item[0], "suggested_db": item[1]} for item in unmatched]
    }

    with open('party_comparison_report.json', 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2)
    print("Report saved to party_comparison_report.json")

if __name__ == '__main__':
    main()
