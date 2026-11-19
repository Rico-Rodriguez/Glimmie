# My coloring pages

Put your own pages here, **one folder per tab** in the coloring book:

```
art/coloring/mine/
  Cats/
    kitty.svg
    sleepy cat.svg
  Unicorns/
    rainbow unicorn.svg
```

- Every folder becomes a tab; its first page (A to Z) is the tab's picture. Tabs sort by folder name, so
  "01 Cats", "02 Unicorns" sets the order. Your tabs come before the built-in ones.
- SVG, PNG and JPG all work. Black lines on white or transparent work best; grey shading is dropped and thin
  lines are thickened so taps fill the right areas.
- Push to `main` and the next build (Actions, "Build iPad app") turns them into pages: the new version shows up
  in Feather like any other update. Unchanged files are skipped, so later builds stay quick.
- Delete or rename a file or folder and the page or tab goes away (or moves) on the next build.

Nothing generated is committed: `tools/build_my_pages.py` runs in the build. To try it locally:
`pip install cairosvg pillow numpy scipy && python3 tools/build_my_pages.py`.
