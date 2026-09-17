# Nose Boop

**Nose Boop is usb-boop's selected visual identity.** Use it as the reference for
future artwork, rather than the earlier icon proposals or the retired glasses
and USB glyph.

The story is simple: the cat boops the connection, and the app reports its link
speed. It comes from the real cats whose interest in cables helped give the app
its name. Keep the character warm, curious, and gently mischievous.

## Full-color icon

A ginger cat with a cream muzzle gently touches a teal USB-C plug with its nose.
A deep navy tile and coral accent frame the moment. Preserve the nose-to-plug
contact and clear silhouette when adapting the artwork to smaller sizes.

The full-color icon identifies the app in Finder, Settings, and macOS
notifications, as well as the README and website. Notification artwork comes
from the app's bundled icon; it is not a separate illustration.

- Canonical artwork: [nose-boop-source.png](../Design/nose-boop-source.png)
- Bundled app sizes: [AppIcon.appiconset](../Sources/App/Assets.xcassets/AppIcon.appiconset)
- README and website image: [icon.png](icon.png)
- Website favicon: [favicon.png](favicon.png)

## Menu bar mark

The menu bar uses a front-facing cat-head silhouette with a bold USB trident
cut out of its center. Alex requested the USB symbol to make the purpose clear
at a glance after the original nose-and-plug miniature proved hard to read.
At 22 points, omit face details and motion marks. Both the outside and the
trident are transparent, so macOS can tint the template for light and dark
appearances. Keep the full Nose Boop illustration for app icons and larger surfaces.

- Canonical artwork: [nose-boop-menu-source.png](../Design/nose-boop-menu-source.png)
- Bundled template sizes: [MenuBarIcon.imageset](../Sources/App/Assets.xcassets/MenuBarIcon.imageset)

## Future references

Refer to this identity by name as **Nose Boop**. Retain the ginger cat, cream
muzzle, teal plug, navy background, and coral accent for full-color adaptations;
use the monochrome companion in the menu bar. New exports should come from the
canonical artwork above so the app, notifications, documentation, and website
continue to look like the same product.

Use [generate_icon_assets.sh](../scripts/generate_icon_assets.sh) to regenerate
the packaged sizes from the approved masters. Ordinary rebuilds reuse this
artwork; they do not generate a new interpretation of Nose Boop.
