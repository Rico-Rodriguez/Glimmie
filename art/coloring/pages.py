"""All Glimmie coloring pages, grouped by category. Original art, drawn in code (see lib.py)."""
from lib import *  # noqa: F401,F403
from pages_animals import ANIMALS
from pages_ocean import OCEAN
from pages_magic import MAGIC
from pages_princess import PRINCESS
from pages_treats import TREATS
from pages_dinos import DINOS
from pages_go import GO
from pages_garden import GARDEN
from pages_space import SPACE
from pages_holiday import HOLIDAY

# icon = SF Symbol shown on the category tab; color = tab color (r, g, b 0-1)
CATEGORIES = [
    {"id": "animals", "icon": "pawprint.fill", "color": [1.0, 0.62, 0.45], "pages": ANIMALS},
    {"id": "magic", "icon": "wand.and.stars", "color": [0.78, 0.55, 1.0], "pages": MAGIC},
    {"id": "princess", "icon": "crown.fill", "color": [1.0, 0.55, 0.78], "pages": PRINCESS},
    {"id": "ocean", "icon": "fish.fill", "color": [0.38, 0.72, 1.0], "pages": OCEAN},
    {"id": "treats", "icon": "birthday.cake.fill", "color": [1.0, 0.7, 0.3], "pages": TREATS},
    {"id": "garden", "icon": "camera.macro", "color": [0.45, 0.82, 0.45], "pages": GARDEN},
    {"id": "dinos", "icon": "lizard.fill", "color": [0.4, 0.78, 0.6], "pages": DINOS},
    {"id": "go", "icon": "car.fill", "color": [1.0, 0.45, 0.45], "pages": GO},
    {"id": "space", "icon": "moon.stars.fill", "color": [0.45, 0.5, 0.95], "pages": SPACE},
    {"id": "holiday", "icon": "gift.fill", "color": [0.95, 0.4, 0.5], "pages": HOLIDAY},
]
