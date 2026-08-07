import csv
import os
import re
import sys

## python3 icon_scanner.py [search_directory] [output_csv_filename]
## this script scans a Godot project for unique missing PNG icon references and logs them to a CSV file.
## great for tracking down missing assets!


def main():
    # Use specified directory or default to current directory
    search_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    output_csv_filename = sys.argv[2] if len(sys.argv) > 2 else "missing_icons.csv"

    abs_target = os.path.abspath(search_dir)

    # 1. Locate Godot Project Root (directory containing project.godot)
    project_root = None
    curr = abs_target
    while curr != os.path.dirname(curr):
        if os.path.exists(os.path.join(curr, "project.godot")):
            project_root = curr
            break
        curr = os.path.dirname(curr)

    if not project_root:
        # Check subdirectories if project.godot is inside search_dir
        for root, dirs, files in os.walk(abs_target):
            if "project.godot" in files:
                project_root = root
                break

    if not project_root:
        project_root = abs_target

    base_dir_name = os.path.basename(project_root)

    print(f"Godot Project Root : {project_root}")
    print(f"Base Directory Name: {base_dir_name}")
    print("Scanning project for unique missing PNG icon references...")

    # Regex matching res://...png (excluding .godot internal cache and sub-resources)
    pattern = re.compile(
        r'res://(?!\.godot/)[^\s\'"\,<>:]+\.png(?=["\'\s,<>:]|$)', re.IGNORECASE
    )

    # File extensions to scan
    valid_extensions = (
        ".gd",
        ".tscn",
        ".tres",
        ".csv",
        ".json",
        ".godot",
        ".xml",
        ".txt",
        ".cfg",
    )

    missing_records = []
    seen_icons = set()  # Deduplicate purely by missing icon path string

    for root, dirs, files in os.walk(project_root):
        # Exclude internal engine and VCS directories
        dirs[:] = [
            d for d in dirs if d not in (".git", ".godot", "node_modules", ".import")
        ]

        for file in files:
            # Ignore sidecar .import files, scripts, and output CSV
            if (
                file.endswith(".import")
                or file.endswith(".py")
                or file.endswith(".sh")
                or file == output_csv_filename
            ):
                continue
            if not file.endswith(valid_extensions):
                continue

            full_file_path = os.path.join(root, file)

            # Format Column 1: e.g. shards/Data/Items/Equipment/LaserDagger.tres
            rel_from_root = os.path.relpath(full_file_path, project_root)
            col1_path = os.path.join(base_dir_name, rel_from_root)

            try:
                with open(full_file_path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                    matches = pattern.findall(content)
                    for res_path in matches:
                        if "::" in res_path or res_path.lower() in (
                            "res://.png",
                            "res://png",
                        ):
                            continue

                        # Convert res:// URI to disk path
                        rel_disk_path = res_path[6:]  # Strip 'res://'
                        actual_disk_path = os.path.join(project_root, rel_disk_path)

                        # Record entry ONLY if the PNG file DOES NOT exist on disk
                        if not os.path.exists(actual_disk_path):
                            icon_key = res_path.lower()
                            if icon_key not in seen_icons:
                                seen_icons.add(icon_key)
                                missing_records.append((col1_path, res_path))
            except Exception:
                pass

    # Save to CSV
    output_path = os.path.join(
        abs_target if os.path.isdir(abs_target) else os.path.dirname(abs_target),
        output_csv_filename,
    )
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["referenced_in", "icon_path"])
        for record in missing_records:
            writer.writerow(record)

    print(
        f"Scan complete! Found {len(missing_records)} unique missing icon(s). Logged to '{output_path}'."
    )


if __name__ == "__main__":
    main()
