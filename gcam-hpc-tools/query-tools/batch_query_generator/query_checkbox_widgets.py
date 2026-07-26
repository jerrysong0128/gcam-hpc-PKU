"""Purpose: Provide checkbox widgets for selecting GCAM queries and regions.

Author: Jingyang Song, Peking University; Jul 2026;
"""

import xml.etree.ElementTree as ET
import csv
import ipywidgets as widgets
from IPython.display import display
from datetime import datetime
import os

def select_queries_and_regions(queries, regions, output_dir="../user_batch_queries"):
    """
    Interactive panel for selecting queries and regions using tick boxes.
    On confirm: saves XML with timestamp and shows the file path.
    """
    # Generated definitions must land beside the ModelInterface batch control.
    os.makedirs(output_dir, exist_ok=True)

    # --- Prepare options with "All" ---
    query_titles = ["All"] + [q.title for q in queries]
    region_titles = ["All"] + regions

    # --- Checkbox groups ---
    region_checks = [widgets.Checkbox(value=False, description=r) for r in region_titles]
    query_checks = [widgets.Checkbox(value=False, description=q) for q in query_titles]

    button = widgets.Button(description="Confirm Selection", button_style='success')
    output = widgets.Output()

    def on_button_clicked(b):
        with output:
            output.clear_output()

            # --- Queries ---
            selected_titles = [cb.description for cb in query_checks if cb.value]
            if "All" in selected_titles:
                queries_needed = queries
            else:
                queries_needed = [q for q in queries if q.title in selected_titles]

            # --- Regions ---
            selected_regions = [cb.description for cb in region_checks if cb.value]
            if "All" in selected_regions:
                regions_needed = regions
            else:
                regions_needed = selected_regions

            # --- Build output filename ---
            timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            output_file = os.path.join(output_dir, f"queries-{timestamp}.xml")

            # --- Save XML ---
            build_query_xml(queries_needed, regions_needed, output_file)

            # --- Feedback ---
            print("✅ Query XML generated!")
            print(f"Saved to: {output_file}")
            print("\nQueries selected:")
            for q in queries_needed:
                print(" -", q.title)
            print("\nRegions selected:")
            for r in regions_needed:
                print(" -", r)

    button.on_click(on_button_clicked)

    # --- Layout ---
    panels = widgets.HBox([
        widgets.VBox([widgets.Label("Regions:")] + region_checks,
                     layout=widgets.Layout(width='25%', height='500px', overflow_y='auto')),
        widgets.VBox([widgets.Label("Queries:")] + query_checks,
                     layout=widgets.Layout(width='65%', height='500px', overflow_y='auto'))
    ])
    display(panels, button, output)


def read_regions_from_csv(csv_path):
    """Read the GCAM region column while ignoring commented mapping rows."""
    regions = []
    with open(csv_path, newline='', encoding='utf-8') as csvfile:
        lines = [line for line in csvfile if not line.startswith('#')] # Skip comment lines
        reader = csv.DictReader(lines)
        for row in reader:
            regions.append(row['region'])
    return regions


def build_query_xml(queries, regions, output_file):
    """Write ModelInterface-compatible aQuery elements for each selection."""
    root = ET.Element("queries")
    for q in queries:
        aquery = ET.SubElement(root, "aQuery")
        for region in regions:
            reg_elem = ET.SubElement(aquery, "region", name=region)
            reg_elem.tail = "\n"
        sdq = ET.fromstring(q.querystr)
        aquery.append(sdq)
        sdq.tail = "\n"
        aquery.tail = "\n"
    tree = ET.ElementTree(root)
    tree.write(output_file, encoding="utf-8", xml_declaration=True)
