#!/usr/bin/env python3

import json
import re
import sys
import subprocess
from pathlib import Path
from urllib.request import urlopen
from datetime import datetime, timezone

README_URL = "https://raw.githubusercontent.com/rooootdev/lara/refs/heads/main/README.md"
AVATAR_URL = "https://avatars.githubusercontent.com/u/103732419?v=4"
HEADER_URL = "https://raw.githubusercontent.com/rooootdev/lara/refs/heads/main/icon.png"
APP_ICON_URL = "https://raw.githubusercontent.com/rooootdev/lara/refs/heads/main/lara.png"

def run(cmd):
	return subprocess.check_output(cmd, text=True).strip()

def fetch_description():
	with urlopen(README_URL) as response:
		text = response.read().decode("utf-8")
	marker = text.find("---")
	if marker == -1:
		raise ValueError('"---" marker not found in README.md')
	text = text[marker + 3:]
	text = re.sub(r"<[^>]+>", "", text)
	text = "\n".join(line.rstrip() for line in text.splitlines())
	text = text.strip()
	text = re.sub(r"\n+", "\n", text)
	return text

def get_recent_commits():
	try:
		commits = run([
			"git",
			"log",
			"--since=12 hours ago",
			"--pretty=format:- %h %s (%an)"
		])
		return commits or "No commits in the last 12 hours"
	except Exception:
		return "No commits in the last 12 hours"

def generate_release_notes(version, iso_date):
	sha = run(["git", "rev-parse", "HEAD"])
	dt = datetime.fromisoformat(
		iso_date.replace("Z", "+00:00")
	).astimezone(timezone.utc)
	built_at_utc = dt.strftime("%a %b %d %H:%M:%S %Y")
	built_at_date = dt.strftime("%Y-%m-%d")
	commits = get_recent_commits()
	text = f"""## Build Info

Built at (UTC): {built_at_utc}
Built at (UTC date): {built_at_date}
Commit SHA: {sha}
Version: {version}

**Changes in the last 12 hours**

{commits}
"""
	text = text.strip()
	text = re.sub(r"\n+", "\n", text)
	return text

def build_source(version, iso_date, repo, size):
	download_url = f"https://github.com/{repo}/releases/download/latest/lara.ipa"
	release_url = f"https://github.com/{repo}/releases/tag/latest"
	description = fetch_description()
	release_notes = generate_release_notes(version, iso_date)
	return {
		"name": "lara",
		"subtitle": "WIP darksword kexploit implement",
		"description": "",
		"iconURL": AVATAR_URL,
		"headerURL": HEADER_URL,
		"website": f"https://github.com/{repo}",
		"tintColor": "#4185A9",
		"featuredApps": [
			"com.roooot.lara"
		],
		"news": [
			{
				"appID": "com.roooot.lara",
				"caption": "Update of lara just got released!",
				"date": iso_date,
				"identifier": f"release-{version}",
				"imageURL": APP_ICON_URL,
				"notify": True,
				"tintColor": "#4185A9",
				"title": f"{version} - lara",
				"url": release_url
			}
		],
		"apps": [
			{
				"name": "lara",
				"bundleIdentifier": "com.roooot.lara",
				"developerName": "rooootdev",
				"subtitle": "iOS 18.7.1- & 26.0.1-",
				"localizedDescription": description,
				"iconURL": APP_ICON_URL,
				"tintColor": "#5CA399",
				"versions": [
					{
						"version": version,
						"date": iso_date,
						"size": size,
						"downloadURL": download_url,
						"localizedDescription": release_notes,
						"minOSVersion": "15.0"
					}
				],
				"appPermissions": {}
			}
		]
	}


def main():
	if len(sys.argv) != 5:
		print(
			"usage: generate_source.py <version> <iso_date> <repo> <size>",
			file=sys.stderr
		)
		sys.exit(1)

	version = sys.argv[1]
	iso_date = sys.argv[2]
	repo = sys.argv[3]
	size = int(sys.argv[4])

	data = build_source(version, iso_date, repo, size)
	Path("build").mkdir(exist_ok=True)
	with open("build/source.json", "w", encoding="utf-8") as f:
		json.dump(data, f, indent=2, ensure_ascii=False)
	print("generated build/source.json")

if __name__ == "__main__":
	main()