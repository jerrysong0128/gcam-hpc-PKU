"""Purpose: Provide notebook widgets for selecting GCAM queries and regions.

Author: Jingyang Song, Peking University; Jul 2026;
"""

import xml.etree.ElementTree as ET
import csv
import ipywidgets as widgets
from IPython.display import display
from datetime import datetime
import os

def select_queries_and_regions(queries, regions, output_dir="../batch-queries"):
    """
    Interactive panel for selecting queries and regions.
    On confirm: saves XML with timestamp and shows the file path.
    """
    # Generated definitions must land beside the ModelInterface batch control.
    os.makedirs(output_dir, exist_ok=True)

    # --- Prepare options with "All" ---
    query_titles = ["All"] + [q.title for q in queries]
    region_titles = ["All"] + regions

    # --- Widgets ---
    select_regions = widgets.SelectMultiple(
        options=region_titles,
        description="Regions:",
        layout=widgets.Layout(width='45%', height='250px')
    )

    select_queries = widgets.SelectMultiple(
        options=query_titles,
        description="Queries:",
        layout=widgets.Layout(width='45%', height='250px')
    )

    button = widgets.Button(description="Confirm Selection", button_style='success')
    output = widgets.Output()

    def on_button_clicked(b):
        with output:
            output.clear_output()

            # --- Queries ---
            selected_titles = list(select_queries.value)
            if "All" in selected_titles:
                queries_needed = queries
            else:
                queries_needed = [q for q in queries if q.title in selected_titles]

            # --- Regions ---
            selected_regions = list(select_regions.value)
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
    panels = widgets.HBox([select_regions, select_queries])
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
