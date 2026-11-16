import argparse
import csv
import os
import re
from collections import defaultdict

## python3 icon_scanner.py [search_directory] [output_csv_filename] [--all]
##
## Scans a Godot project for image references (res://...png/jpg/jpeg/webp/svg/tga/bmp) that won't
## load, and writes one row per broken image to a CSV (default: missing_icons.csv in the project root).
##
## Each row has a status:
##   MISSING     - no file at that path. Make the icon (or fix the path; see "suggestion").
##   WRONG_CASE  - the file exists but with different capitals (e.g. Assets/ vs assets/). Works in
##                 the editor on macOS/Windows, breaks in exported builds (the .pck is case-sensitive).
##   STALE_PATH  - no file at that path, but the reference's uid still finds the file elsewhere,
##                 so it loads today. Re-save the scene/resource in Godot to refresh the path.
##
## "suggestion" lists files elsewhere in the project with the same file name (moved / renamed icons).
## "referenced_in" lists every file that uses the image, so fixing the CSV row fixes them all.
##
## By default it skips folders that never ship (build/, android/, _extra/, _backup*, tests/,
## _documentation/, addons/gut/). Pass --all to scan those too.
##
## Not caught: paths built in code at runtime (e.g. FUR_DIR + breed + ".png"); check those by hand.

IMAGE_EXTENSIONS = ("png", "jpg", "jpeg", "webp", "svg", "tga", "bmp")
SCAN_EXTENSIONS = (".gd", ".tscn", ".tres", ".csv", ".json", ".godot", ".xml", ".txt", ".cfg", ".gdshader")
ALWAYS_SKIP_DIRS = {".git", ".godot", ".import", "node_modules", "__pycache__"}
# Not exported (see export_presets.cfg exclude_filter) - skipped unless --all.
NON_SHIPPING_DIRS = ("build", "android", "_extra", "tests", "_documentation", "addons/gut")
NON_SHIPPING_PREFIXES = ("_backup",)

# res://some/path/file.png - may contain spaces; stops at quotes, commas, newlines, "::" sub-resources.
REF_PATTERN = re.compile(
    r"res://(?!\.godot/)[^\"'\n\r,<>|*?:]*?\.(?:" + "|".join(IMAGE_EXTENSIONS) + r")(?![A-Za-z0-9_])",
    re.IGNORECASE,
)
# [ext_resource ... uid="uid://x" ... path="res://y"] - lets STALE_PATH tell a dead path from a moved file.
EXT_RESOURCE_PATTERN = re.compile(r"\[ext_resource[^\]]*?uid=\"(uid://[^\"]+)\"[^\]]*?path=\"(res://[^\"]+)\"")
IMPORT_UID_PATTERN = re.compile(r'^uid="(uid://[^"]+)"', re.MULTILINE)


def find_project_root(target):
    curr = target
    while curr != os.path.dirname(curr):
        if os.path.exists(os.path.join(curr, "project.godot")):
            return curr
        curr = os.path.dirname(curr)
    for root, _dirs, files in os.walk(target):
        if "project.godot" in files:
            return root
    return target


def is_non_shipping(rel_dir):
    rel_dir = os.path.normpath(rel_dir).replace(os.sep, "/")
    if rel_dir in ("", "."):
        return False
    for d in NON_SHIPPING_DIRS:
        if rel_dir == d or rel_dir.startswith(d + "/"):
            return True
    first = rel_dir.split("/")[0]
    return any(first.startswith(p) for p in NON_SHIPPING_PREFIXES)


class ExactCaseChecker:
    """os.path.exists ignores capitals on macOS/Windows; exported builds don't. This doesn't."""

    def __init__(self, root):
        self.root = root
        self.listings = {}

    def _list(self, directory):
        if directory not in self.listings:
            try:
                self.listings[directory] = os.listdir(directory)
            except OSError:
                self.listings[directory] = []
        return self.listings[directory]

    def check(self, rel_path):
        """Returns ("ok", None), ("case", real_rel_path) or ("missing", None)."""
        current = self.root
        real_parts = []
        wrong_case = False
        for part in rel_path.split("/"):
            if not part:
                continue
            entries = self._list(current)
            if part in entries:
                real = part
            else:
                matches = [e for e in entries if e.lower() == part.lower()]
                if not matches:
                    return "missing", None
                real = matches[0]
                wrong_case = True
            real_parts.append(real)
            current = os.path.join(current, real)
        if wrong_case:
            return "case", "/".join(real_parts)
        return "ok", None


def main():
    parser = argparse.ArgumentParser(description="Find image references in a Godot project that won't load.")
    parser.add_argument("search_dir", nargs="?", default=".")
    parser.add_argument("output_csv", nargs="?", default="missing_icons.csv")
    parser.add_argument("--all", action="store_true", help="also scan folders that aren't exported")
    args = parser.parse_args()

    project_root = find_project_root(os.path.abspath(args.search_dir))
    output_name = os.path.basename(args.output_csv)
    print(f"Godot Project Root : {project_root}")
    print(f"Scanning for broken image references ({', '.join(IMAGE_EXTENSIONS)})"
          + (" in ALL folders..." if args.all else " in shipped folders (use --all for everything)..."))

    checker = ExactCaseChecker(project_root)
    uid_to_path = {}              # uid://... -> res://... (from .import files)
    images_by_name = defaultdict(list)  # lower-case file name -> [res:// paths]
    references = defaultdict(set)       # res:// path as written -> {files that reference it}
    ref_uids = defaultdict(set)         # res:// path as written -> {uids it was written with}

    for root, dirs, files in os.walk(project_root):
        rel_dir = os.path.relpath(root, project_root)
        dirs[:] = [
            d for d in dirs
            if d not in ALWAYS_SKIP_DIRS
            and (args.all or not is_non_shipping(os.path.join(rel_dir, d)))
        ]
        rel_dir_posix = "" if rel_dir == "." else rel_dir.replace(os.sep, "/") + "/"

        for name in files:
            full_path = os.path.join(root, name)
            rel_file = rel_dir_posix + name

            if name.endswith(".import"):
                try:
                    with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                        match = IMPORT_UID_PATTERN.search(f.read())
                    if match:
                        uid_to_path[match.group(1)] = "res://" + rel_file[: -len(".import")]
                except OSError:
                    pass
                continue

            if name.lower().endswith(tuple("." + e for e in IMAGE_EXTENSIONS)):
                images_by_name[name.lower()].append("res://" + rel_file)
                continue

            if name == output_name or not name.endswith(SCAN_EXTENSIONS):
                continue
            try:
                with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
            except OSError:
                continue
            for res_path in REF_PATTERN.findall(content):
                references[res_path].add(rel_file)
            for uid, res_path in EXT_RESOURCE_PATTERN.findall(content):
                ref_uids[res_path].add(uid)

    rows = []
    for res_path, referenced_in in references.items():
        status, real_path = checker.check(res_path[len("res://"):])
        if status == "ok":
            continue
        suggestion = ""
        if status == "case":
            kind = "WRONG_CASE"
            suggestion = "res://" + real_path
        else:
            resolved = [uid_to_path[u] for u in ref_uids.get(res_path, ()) if u in uid_to_path]
            resolved = [p for p in resolved if checker.check(p[len("res://"):])[0] == "ok"]
            if resolved:
                kind = "STALE_PATH"
                suggestion = resolved[0]
            else:
                kind = "MISSING"
                same_name = images_by_name.get(os.path.basename(res_path).lower(), [])
                suggestion = " ; ".join(sorted(same_name)[:3])
        rows.append((kind, res_path, suggestion, len(referenced_in), " ; ".join(sorted(referenced_in))))

    order = {"WRONG_CASE": 0, "MISSING": 1, "STALE_PATH": 2}
    rows.sort(key=lambda r: (order[r[0]], os.path.dirname(r[1]).lower(), r[1].lower()))

    output_path = args.output_csv if os.path.isabs(args.output_csv) else os.path.join(project_root, args.output_csv)
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["status", "icon_path", "suggestion", "ref_count", "referenced_in"])
        writer.writerows(rows)

    counts = defaultdict(int)
    for row in rows:
        counts[row[0]] += 1
    print(f"Scanned {len(references)} unique image references.")
    print(f"  MISSING    : {counts['MISSING']:4d}  (icon doesn't exist - make it or fix the path)")
    print(f"  WRONG_CASE : {counts['WRONG_CASE']:4d}  (works in editor, breaks in exports)")
    print(f"  STALE_PATH : {counts['STALE_PATH']:4d}  (loads via uid; re-save to refresh path)")
    by_folder = defaultdict(int)
    for row in rows:
        if row[0] == "MISSING":
            by_folder[os.path.dirname(row[1])] += 1
    if by_folder:
        print("Missing icons by folder:")
        for folder, n in sorted(by_folder.items(), key=lambda kv: -kv[1]):
            print(f"  {n:4d}  {folder}/")
    print(f"Logged {len(rows)} row(s) to '{output_path}'.")


if __name__ == "__main__":
    main()
