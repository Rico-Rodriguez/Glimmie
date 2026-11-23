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
# Keep each version to the fields Feather's own sample source uses (claration/feather app-repo.json).
entry = {"version": version, "date": date, "size": size, "downloadURL": url}
keep = ("version", "date", "size", "downloadURL")
# These builds include the retired game. Keep them out of the sideload feed.
retired = {'1.0.215', '1.0.219', '1.0.222', '1.0.235', '1.0.237'}
versions = [entry] + [
    {k: v[k] for k in keep if k in v}
    for v in old if v.get('version') not in retired | {version}
][:9]

source = {
    "name": "Glimmie",
    "identifier": "com.glimmie.source",
    "subtitle": "A drawer of kids' games, with no ads and nothing to buy",
    "description": "Builds of Glimmie, a drawer of kids' games for iPad and iPhone.",
    "iconURL": f"{RAW}/App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    "website": f"https://github.com/{REPO}",
    "tintColor": "FF8FC4",
    "apps": [{
        "name": "Glimmie",
        "bundleIdentifier": "com.glimmie.closet",
        "developerName": "Glimmie",
        "subtitle": "Kids' game drawer",
        "localizedDescription": "A drawer of kids' games. Dress Up: a chibi doll with hundreds of hair, face, clothes and accessory choices, colors, patterns, scenes and a photo gallery. Everything is free: no ads, no purchases, nothing locked.",
        "iconURL": f"{RAW}/App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
        "tintColor": "FF8FC4",
        "screenshotURLs": [f"{RAW}/docs/screenshots/{n}.jpg" for n in ("1-drawer", "2-dressup", "4-dressup-clothes")],
        "versions": versions,
        # legacy single-version fields, still read by some clients
        "version": version, "versionDate": date, "downloadURL": url, "size": size,
        # Older Feather builds fail on "privacy": {} (they expect an array), so leave it empty like Feather's sample.
        "appPermissions": {},
    }],
    "news": [],
}
json.dump(source, open('source.json', 'w'), indent=2)
print('source.json ->', version, url)
