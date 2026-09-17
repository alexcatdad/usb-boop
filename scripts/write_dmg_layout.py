"""Write per-image Finder metadata without automating or changing Finder."""
import sys
from pathlib import Path

from ds_store import DSStore
from mac_alias import Alias

volume = Path(sys.argv[1]).resolve()
background = Alias.for_file(str(volume / '.background/background.png')).to_bytes()
with DSStore.open(str(volume / '.DS_Store'), 'w+') as store:
    store['.']['bwsp'] = {
        'ShowStatusBar': False, 'ShowToolbar': False, 'ShowTabView': False,
        'ShowPathbar': False, 'ShowSidebar': False, 'ContainerShowSidebar': False,
        'WindowBounds': '{{140, 120}, {640, 448}}',
    }
    store['.']['icvp'] = {
        'backgroundType': 2, 'backgroundImageAlias': background,
        'backgroundColorRed': 1.0, 'backgroundColorGreen': 1.0,
        'backgroundColorBlue': 1.0, 'gridOffsetX': 0.0, 'gridOffsetY': 0.0,
        'gridSpacing': 100.0, 'arrangeBy': 'none', 'showIconPreview': True,
        'showItemInfo': False, 'labelOnBottom': True, 'textSize': 14.0,
        'iconSize': 112.0, 'viewOptionsVersion': 1,
    }
    store['.']['vSrn'] = ('long', 1)
    store['.']['icvl'] = ('type', b'icnv')
    store['usb-boop.app']['Iloc'] = (170, 200)
    store['Applications']['Iloc'] = (470, 200)
