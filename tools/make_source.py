"""Write/refresh source.json: an AltStore-style app source that Feather (and AltStore/SideStore) can add.
usage: python3 tools/make_source.py VERSION BUILD IPA_URL IPA_SIZE_BYTES"""
import json, os, sys, datetime

REPO = os.environ.get('GITHUB_REPOSITORY', 'Rico-Rodriguez/Glimmie')
RAW = f'https://raw.githubusercontent.com/{REPO}/main'
version, build, url, size = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
date = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

old = []
if os.path.exists('source.json'):
    try:
        old = json.load(open('source.json'))['apps'][0].get('versions', [])
    except Exception:
        old = []
entry = {"version": version, "buildVersion": build, "date": date, "downloadURL": url, "size": size,
         "localizedDescription": f"Build {build}", "minOSVersion": "16.0"}
versions = [entry] + [v for v in old if v.get('version') != version][:9]

source = {
    "name": "Glimmie",
    "identifier": "com.glimmie.source",
    "subtitle": "Glimmie Closet dress-up sticker game",
    "description": "Builds of Glimmie Closet, a dress-up sticker game for iPad.",
    "iconURL": f"{RAW}/App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    "website": f"https://github.com/{REPO}",
    "tintColor": "#FF8FC4",
    "apps": [{
        "name": "Glimmie",
        "bundleIdentifier": "com.glimmie.closet",
        "developerName": "Glimmie",
        "subtitle": "Dress-up sticker game",
        "localizedDescription": "Design your own girl, drag stickers to dress her up, grant Glimmie wishes, fill the star jar and hatch magic eggs.",
        "iconURL": f"{RAW}/App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
        "tintColor": "#FF8FC4",
        "category": "games",
        "screenshotURLs": [f"{RAW}/docs/screenshots/{n}.jpg" for n in ("1-avatar-maker", "3-boutique-wish", "4-egg")],
        "versions": versions,
        # legacy single-version fields, still read by some clients
        "version": version, "versionDate": date, "downloadURL": url, "size": size,
        "appPermissions": {"entitlements": [], "privacy": {}},
    }],
    "news": [],
}
json.dump(source, open('source.json', 'w'), indent=2)
print('source.json ->', version, url)
