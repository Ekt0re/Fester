import json
import os

base_path = r"assets/translations"
it_file = os.path.join(base_path, "it-IT.json")

with open(it_file, 'r', encoding='utf-8') as f:
    it_data = json.load(f)

# Keys to sync
dashboard_keys = it_data["dashboard"]
people_counter_section = it_data["people_counter"]
common_keys = it_data["common"]

# Languages to sync
languages = ["en-US.json", "es-ES.json", "fr-FR.json", "de-DE.json", "zh-CN.json"]

# Rough translations for new keys
translations = {
    "en-US.json": {
        "dashboard": {
            "advanced_stats": "Advanced Stats",
            "quick_menu": "Quick Menu",
            "people_counter": "People Counter",
            "manage_event": "Manage Event",
            "event": "Event",
            "no_description": "No description",
            "nav": {
                "home": "Home",
                "search": "Search",
                "notifications": "Notifications",
                "menu": "Menu"
            }
        },
        "people_counter": {
            "title": "People Counter",
            "no_areas": "No areas created",
            "counters_tab": "Counters",
            "stats_tab": "Statistics",
            "success_move": "Person moved successfully",
            "success_remove": "Person removed from area",
            "remove_error": "Error during removal: ",
            "add_area_title": "New Area",
            "area_name_label": "Area Name (e.g. Ground Floor)",
            "area_name_hint": "Enter name",
            "create_button": "Create",
            "delete_confirm_title": "Delete {}?",
            "delete_confirm_content": "This action cannot be undone. All data related to this area will be lost.",
            "delete_button": "Delete",
            "total_participants": "Total Participants",
            "current_distribution": "Current Distribution",
            "no_current_data": "No current data",
            "history_over_time": "History Over Time",
            "no_history_available": "No history available"
        },
        "common": {
            "ok": "OK",
            "app_title": "FESTER 3.0",
            "error_prefix": "Error: ",
            "organize_party": "ORGANIZE YOUR PARTY!"
        }
    }
}

for lang in languages:
    filepath = os.path.join(base_path, lang)
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        continue
    
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Update common
    if "common" not in data: data["common"] = {}
    lang_common = translations.get(lang, translations["en-US.json"])["common"]
    data["common"].update(lang_common)
    
    # Update dashboard
    if "dashboard" not in data: data["dashboard"] = {}
    lang_dash = translations.get(lang, translations["en-US.json"])["dashboard"]
    data["dashboard"].update(lang_dash)
    
    # Update people_counter
    lang_pc = translations.get(lang, translations["en-US.json"])["people_counter"]
    data["people_counter"] = lang_pc
    
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=4)
    
    print(f"Synchronized {lang}")
