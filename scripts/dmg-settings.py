import os

root = os.getcwd()
defines = dict(globals().get("defines") or {})

app = defines.get("app") or os.path.join(root, "build/dmg-derived/Build/Products/Release/reMouse.app")
icon = defines.get("icon") or os.path.join(app, "Contents/Resources/AppIcon.icns")
background = defines.get("background") or os.path.join(root, "design/dmg/background.png")

volume_name = "reMouse"
format = "UDZO"
filesystem = "HFS+"

files = [app]
symlinks = {"Applications": "/Applications"}

window_rect = ((240, 140), (660, 488))
default_view = "icon-view"
icon_size = 128
text_size = 12
show_icon_preview = True
show_toolbar = False
show_status_bar = False
show_tab_view = False
show_pathbar = False
show_sidebar = False

icon_locations = {
    "reMouse.app": (165, 190),
    "Applications": (495, 190),
}
