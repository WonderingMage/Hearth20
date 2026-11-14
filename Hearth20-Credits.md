# Hearth20 Beta — asset credits

Original foundation: Hearthtable (CC0), retained in THIRD_PARTY/Hearthtable-CC0.txt. Godot engine license: THIRD_PARTY/Godot-MIT.txt. Models and SDK components retain their individual licenses.



hearth20/menu_art/CREDITS.md

# Menu artwork

The revised party illustration was supplied by the Hearth20 creator as
`Gemini_Generated_Image_1dm2nz1dm2nz1dm2.jpg`.

`party-revised.jpg` is a byte-for-byte copy of that 2752 × 1536 JPG.
Its faces, composition and physical details were not repainted. The separate
transparent `rage-overlay.png` was generated with the built-in image tool to
add crimson rage mist and weapon glows to the two axe-wielding warriors.
The additive display shader excludes their face areas and preserves the base
artwork. See `rage-overlay-prompt.json` for the generation prompt. The earlier
`party-original.jpg` remains in source for provenance; it is not the active menu.

The image imports losslessly with mipmaps. A mild, range-limited display shader
sharpens existing detail; it does not generate new facial detail or claim to
recover information absent from the original image.


hearth20/generated_models/CREDITS.md

# Hearth20 static tavern assets

The reconstructed room and generated props were supplied by the Hearth20 creator. Original GLBs are retained outside the runtime project in `Hearth20 Development/generated models`.

These additional kits were supplied in the same folder:

- "Stylized Low-poly Wooden beam" by Rocco Giandomenico: https://sketchfab.com/3d-models/stylized-low-poly-wooden-beam-01b16abea26646c8ba334c905374f83e — author: https://sketchfab.com/Rocco.Giandomenico
- "Stylized Modular Stonewalls" by @blue.blender.print: https://sketchfab.com/3d-models/stylized-modular-stonewalls-4477c00b74574ab9a413dfd76e2362ce — author: https://sketchfab.com/arobaco
- "Tileable Stylized Wooden Floor Texture" by JennyB: https://sketchfab.com/3d-models/tileable-stylized-wooden-floor-texture-167a3fd14d65456dacfacd9eee793e6f — author: https://sketchfab.com/jenny77

All three kits are licensed under Creative Commons Attribution 4.0: https://creativecommons.org/licenses/by/4.0/

Modifications: Godot conversion, stripped unused static vertex channels, resized and block-compressed textures with mipmaps, material finish adjustments, fitted/rotated/instanced meshes, selected atlas regions and projection backfill for the reconstructed room. The authors do not endorse Hearth20.

The room uses a reduced image-grid mesh with its original photo and UV mapping; the main table uses a simplified mesh preserving its UVs. Detached fragments were removed from selected generated props. Animated rulebook, live map/sheet surfaces, special dice and the supplied animated lizard remain separate from the static replacements.


The following title-desert prototype is retained only in the source archive; it is not the released menu or a portable runtime asset.


hearth20/title_desert/CREDITS.md

# The Amber Wastes

## Tarrasque sculpt

Tarrasque Updated by Miguel Zavala, mz4250. Creative Commons Attribution. The original downloadable rigged Blender file is the basis of this model. Retain this attribution with redistributed copies. [Creator's model](https://www.printables.com/model/50569-tarrasque-updated)

Hearth20 modifications include runtime mesh reduction, UV mapping, baked cavity occlusion, anatomical skin and oral surfaces, skinned amber irises and slit pupils, keratin horns and claws, normalized scale, the twenty-second skeletal idle animation, lighting and presentation. Boundary coverage blends skin, gums and tooth roots. The runtime model has 107 bones and approximately 210,000 body triangles. The original creator retains credit for the sculpt and original rig.

## Environment and surface assets

The ancient hide texture, wind-carved sand texture and distant desert matte were generated with the built-in image-generation tool. The creature, foreground terrain, ruined gate, scale markers, lighting, shadows and moving sand sheets render in 3D. The distant landscape is a painted backdrop. Prompts and asset provenance are recorded in asset-prompts.json.

The title owns a separate, bounded-resolution viewport. It releases that world when the table opens. The older rotating creature showcases are excluded from current portable exports.

## Editing

tools/prepare_title_tarrasque.py adapts the creator's rigged Blender source and exports tarrasque.glb. The source Blender file is retained in the development art/title-desert folder. Use Blender 4.5.3 to run the preparation script. The source archive includes the texture import settings and mipmaps used by the runtime export.


hearth20/refreshments/CREDITS.txt

HEARTH20 REFRESHMENTS — ASSET CREDITS
Supplied 3D models, licensed CC-BY-4.0. Food models split into individual servings; dimensions normalized for the side table.

Model Information:
* title:	Beer Mug Glass
* source:	https://sketchfab.com/3d-models/beer-mug-glass-e971453ae97043a2b1348faf36065fed
* author:	i-m-a-kitty-cat (https://sketchfab.com/i-m-a-kitty-cat)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Beer Mug Glass" (https://sketchfab.com/3d-models/beer-mug-glass-e971453ae97043a2b1348faf36065fed) by i-m-a-kitty-cat (https://sketchfab.com/i-m-a-kitty-cat) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
Model Information:
* title:	Less healthy food pack
* source:	https://sketchfab.com/3d-models/less-healthy-food-pack-359d82bcbafa427daeb12371323c4212
* author:	Pneshik (https://sketchfab.com/Pneshik)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Less healthy food pack" (https://sketchfab.com/3d-models/less-healthy-food-pack-359d82bcbafa427daeb12371323c4212) by Pneshik (https://sketchfab.com/Pneshik) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
Model Information:
* title:	Soda Cans
* source:	https://sketchfab.com/3d-models/soda-cans-4e0be610db9646929d8be84491f1a72f
* author:	Anthony Yanez (https://sketchfab.com/paulyanez)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Soda Cans" (https://sketchfab.com/3d-models/soda-cans-4e0be610db9646929d8be84491f1a72f) by Anthony Yanez (https://sketchfab.com/paulyanez) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
Model Information:
* title:	Water Bottle
* source:	https://sketchfab.com/3d-models/water-bottle-db2433b325824ff299351fbd057c0153
* author:	ASA21 (https://sketchfab.com/ASA21)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Water Bottle" (https://sketchfab.com/3d-models/water-bottle-db2433b325824ff299351fbd057c0153) by ASA21 (https://sketchfab.com/ASA21) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
Food and drink Foley: BigSoundBank, CC0. Recordings trimmed, filtered, normalized and faded.
https://bigsoundbank.com/pack-of-chips-opening-s1431.html
https://bigsoundbank.com/eating-potato-chips-1-s1430.html
https://bigsoundbank.com/mouth-noises-1-s0352.html
https://bigsoundbank.com/eat-a-rusk-s0407.html
Drink from the gourd #1 — Joseph SARDIN & Axeline T. https://bigsoundbank.com/drink-from-the-gourd-1-s3247.html
Licking #2 — DenisChardonnet. https://bigsoundbank.com/licking-2-s0239.html
Wake-up audio: models/youre-finally-awake.mp3 supplied by the user, copied without modification as audio/wake.mp3. This clip is not covered by the CC0 recording credits above.


docs/hearth20-creature-credits.md

# Supplied creature showcase credits

Attributions are retained from the owner-supplied archives. These retired showcase assets remain in the source archive. The current title's tarrasque attribution is in hearth20/title_desert/CREDITS.md.

## beholder

Model Information:
* title:	Animated Beholder (Dungeons & Dragons)
* source:	https://sketchfab.com/3d-models/animated-beholder-dungeons-dragons-b0fa0199cd74478fa1c46abc1ecc7adb
* author:	Anthony Yanez (https://sketchfab.com/paulyanez)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Animated Beholder (Dungeons & Dragons)" (https://sketchfab.com/3d-models/animated-beholder-dungeons-dragons-b0fa0199cd74478fa1c46abc1ecc7adb) by Anthony Yanez (https://sketchfab.com/paulyanez) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## kobold

Model Information:
* title:	Animated Kobold
* source:	https://sketchfab.com/3d-models/animated-kobold-0da9989223424d4d80137c0bbf4979fa
* author:	greeneyed3DArtist (https://sketchfab.com/greeneyes3DArtist)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Animated Kobold" (https://sketchfab.com/3d-models/animated-kobold-0da9989223424d4d80137c0bbf4979fa) by greeneyed3DArtist (https://sketchfab.com/greeneyes3DArtist) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## carrion-crawler

Model Information:
* title:	Carrion Crawler
* source:	https://sketchfab.com/3d-models/carrion-crawler-dfd3fd62a0114ad3a7649c679e48314c
* author:	twedo565 (https://sketchfab.com/twedo565)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Carrion Crawler" (https://sketchfab.com/3d-models/carrion-crawler-dfd3fd62a0114ad3a7649c679e48314c) by twedo565 (https://sketchfab.com/twedo565) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## basilisk

Model Information:
* title:	Coiled Basilisk Snake [MESHY]
* source:	https://sketchfab.com/3d-models/coiled-basilisk-snake-meshy-5192ced444d64546af7428ccbb366f39
* author:	EthanFromEngland (https://sketchfab.com/EthanfromEngland)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Coiled Basilisk Snake [MESHY]" (https://sketchfab.com/3d-models/coiled-basilisk-snake-meshy-5192ced444d64546af7428ccbb366f39) by EthanFromEngland (https://sketchfab.com/EthanfromEngland) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## wraith

Model Information:
* title:	Death Star Asuirila Shadow Wraith
* source:	https://sketchfab.com/3d-models/death-star-asuirila-shadow-wraith-622cf16de38f4bc3afbf5c83870f96df
* author:	patromes (https://sketchfab.com/patromes)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Death Star Asuirila Shadow Wraith" (https://sketchfab.com/3d-models/death-star-asuirila-shadow-wraith-622cf16de38f4bc3afbf5c83870f96df) by patromes (https://sketchfab.com/patromes) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## mimic

Model Information:
* title:	DnD_mimic
* source:	https://sketchfab.com/3d-models/dnd-mimic-be3e8759772a48d0bc3d5433edbfb7c7
* author:	Eclipsekn (https://sketchfab.com/Eclipsekn)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "DnD_mimic" (https://sketchfab.com/3d-models/dnd-mimic-be3e8759772a48d0bc3d5433edbfb7c7) by Eclipsekn (https://sketchfab.com/Eclipsekn) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## giant-spider

Model Information:
* title:	Elemental Spider
* source:	https://sketchfab.com/3d-models/elemental-spider-3f5ea19aff254877b9eb5a89f2db7951
* author:	ArachnoBoy (https://sketchfab.com/vang807)

Model License:
* license type:	CC-BY-NC-SA-4.0 (http://creativecommons.org/licenses/by-nc-sa/4.0/)
* requirements:	Author must be credited. No commercial use. Modified versions must have the same license.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Elemental Spider" (https://sketchfab.com/3d-models/elemental-spider-3f5ea19aff254877b9eb5a89f2db7951) by ArachnoBoy (https://sketchfab.com/vang807) licensed under CC-BY-NC-SA-4.0 (http://creativecommons.org/licenses/by-nc-sa/4.0/)

## goblin

Model Information:
* title:	goblin
* source:	https://sketchfab.com/3d-models/goblin-1dbcfa5a93ec4584b4368babef51b443
* author:	konkulie (https://sketchfab.com/konkylie)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "goblin" (https://sketchfab.com/3d-models/goblin-1dbcfa5a93ec4584b4368babef51b443) by konkulie (https://sketchfab.com/konkylie) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## mind-flayer

Model Information:
* title:	Mind flayer / Illithid
* source:	https://sketchfab.com/3d-models/mind-flayer-illithid-50c6cc33366449be873b785c3b1efab6
* author:	filobus (https://sketchfab.com/filobus)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Mind flayer / Illithid" (https://sketchfab.com/3d-models/mind-flayer-illithid-50c6cc33366449be873b785c3b1efab6) by filobus (https://sketchfab.com/filobus) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## orc

Model Information:
* title:	Orc shaman
* source:	https://sketchfab.com/3d-models/orc-shaman-e1c7d1da70854278a728742f7bb98c9b
* author:	valkiriaixda (https://sketchfab.com/valkiriaixda)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Orc shaman" (https://sketchfab.com/3d-models/orc-shaman-e1c7d1da70854278a728742f7bb98c9b) by valkiriaixda (https://sketchfab.com/valkiriaixda) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## owlbear

Model Information:
* title:	Owlbear
* source:	https://sketchfab.com/3d-models/owlbear-b073d2499a7a40528d3000bebcd65783
* author:	Spinnee (https://sketchfab.com/Spinnee)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Owlbear" (https://sketchfab.com/3d-models/owlbear-b073d2499a7a40528d3000bebcd65783) by Spinnee (https://sketchfab.com/Spinnee) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## purple-worm

Model Information:
* title:	purple worm
* source:	https://sketchfab.com/3d-models/purple-worm-4b7d6c4fdd0548a8ba208e64be7c0d29
* author:	hugobart (https://sketchfab.com/hugobart)

Model License:
* license type:	CC-BY-NC-SA-4.0 (http://creativecommons.org/licenses/by-nc-sa/4.0/)
* requirements:	Author must be credited. No commercial use. Modified versions must have the same license.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "purple worm" (https://sketchfab.com/3d-models/purple-worm-4b7d6c4fdd0548a8ba208e64be7c0d29) by hugobart (https://sketchfab.com/hugobart) licensed under CC-BY-NC-SA-4.0 (http://creativecommons.org/licenses/by-nc-sa/4.0/)

## adult-red-dragon

Model Information:
* title:	Red Dragon - Dungeons and Dragons
* source:	https://sketchfab.com/3d-models/red-dragon-dungeons-and-dragons-bdfabc5038044ea0b15e9b27a2d5b998
* author:	Brian Trepanier (https://sketchfab.com/CMBC)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Red Dragon - Dungeons and Dragons" (https://sketchfab.com/3d-models/red-dragon-dungeons-and-dragons-bdfabc5038044ea0b15e9b27a2d5b998) by Brian Trepanier (https://sketchfab.com/CMBC) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## rust-monster

Model Information:
* title:	Rust Monster
* source:	https://sketchfab.com/3d-models/rust-monster-a5645f1bf8274a30aa5f099c9868ca2d
* author:	Miniature Collectors Club (https://sketchfab.com/Alberto.Zanini)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Rust Monster" (https://sketchfab.com/3d-models/rust-monster-a5645f1bf8274a30aa5f099c9868ca2d) by Miniature Collectors Club (https://sketchfab.com/Alberto.Zanini) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## troll

Model Information:
* title:	Troll
* source:	https://sketchfab.com/3d-models/troll-94b4a00a72bb4450b82b7a9c6bd4b177
* author:	kenchoo (https://sketchfab.com/kenchoo)

Model License:
* license type:	CC-BY-NC-SA-4.0 (http://creativecommons.org/licenses/by-nc-sa/4.0/)
* requirements:	Author must be credited. No commercial use. Modified versions must have the same license.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Troll" (https://sketchfab.com/3d-models/troll-94b4a00a72bb4450b82b7a9c6bd4b177) by kenchoo (https://sketchfab.com/kenchoo) licensed under CC-BY-NC-SA-4.0 (http://creativecommons.org/licenses/by-nc-sa/4.0/)

## zombie

Model Information:
* title:	Zombie Scream
* source:	https://sketchfab.com/3d-models/zombie-scream-e1233ae435184964ba0579bf22d97545
* author:	Juangamer (https://sketchfab.com/Juangamer)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Zombie Scream" (https://sketchfab.com/3d-models/zombie-scream-e1233ae435184964ba0579bf22d97545) by Juangamer (https://sketchfab.com/Juangamer) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## ogre

Model Information:
* title:	The Elder Scrolls Blades Ogre
* source:	https://sketchfab.com/3d-models/the-elder-scrolls-blades-ogre-f52616363be045209b6d1564634d5ebc
* author:	OrangeSauceu (https://sketchfab.com/orangesauceu)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "The Elder Scrolls Blades Ogre" (https://sketchfab.com/3d-models/the-elder-scrolls-blades-ogre-f52616363be045209b6d1564634d5ebc) by OrangeSauceu (https://sketchfab.com/orangesauceu) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## skeleton

Skeleton video supplied by the campaign owner. Converted from MP4 to Ogg Theora/Vorbis for native looping playback, with the original audio retained.

## gibbering-mouther

Model Information:
* title:	GIBBERING 2
* source:	https://sketchfab.com/3d-models/gibbering-2-25e48f2a698d4d39ad50104b5d35aace
* author:	julionavarro98 (https://sketchfab.com/julionavarro98)

Model License:
* license type:	CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
* requirements:	Author must be credited. Commercial use is allowed.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "GIBBERING 2" (https://sketchfab.com/3d-models/gibbering-2-25e48f2a698d4d39ad50104b5d35aace) by julionavarro98 (https://sketchfab.com/julionavarro98) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
Hearth20 modification: procedural mottled flesh, fine veins, pores and a wet clearcoat material.

## gelatinous-cube

Model Information:
* title:	Gelatinous Cube
* source:	https://sketchfab.com/3d-models/gelatinous-cube-e08385238f4d4b59b012233a9fbdca21
* author:	glenatron (https://sketchfab.com/glenatron)

Model License:
* license type:	CC-BY-NC-4.0 (http://creativecommons.org/licenses/by-nc/4.0/)
* requirements:	Author must be credited. No commercial use.

If you use this 3D model in your project be sure to copy paste this credit wherever you share it:
This work is based on "Gelatinous Cube" (https://sketchfab.com/3d-models/gelatinous-cube-e08385238f4d4b59b012233a9fbdca21) by glenatron (https://sketchfab.com/glenatron) licensed under CC-BY-NC-4.0 (http://creativecommons.org/licenses/by-nc/4.0/)


hearth20/dice_sets/credits.json

{
  "license": "CC BY 4.0",
  "license_url": "https://creativecommons.org/licenses/by/4.0/",
  "player": {
    "title": "RPG Dice Set",
    "author": "ghosted",
    "author_url": "https://sketchfab.com/dianaavlis2002",
    "source": "https://sketchfab.com/3d-models/rpg-dice-set-2498c370c56842f89fa3d7096c72ed56"
  },
  "dm": {
    "title": "Dungeons and Dragons Dice Set",
    "author": "JayDesigns3D",
    "author_url": "https://sketchfab.com/JayDesigns",
    "source": "https://sketchfab.com/3d-models/dungeons-and-dragons-dice-set-163950cff9694fe1a686d22fe7737236"
  },
  "changes": "Converted from user-supplied glTF archives; normalized solids; bundled original materials; calibrated printed values and corner d4 outcomes. Ordinary DM d10 replaces sculpted tens with amber ones numerals; original tens retained for percentile rolls. Collection names and thumbnails added."
}

hearth20/casino/lizard-credits.json

{
  "title": "Lizard",
  "author": "Froggreen (https://sketchfab.com/Froggreen)",
  "license": "CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)",
  "source": "https://sketchfab.com/3d-models/lizard-2405fa5c4338474ebb646a21aaf81f2d",
  "archive_sha256": "8accb2b9951ed9d46bdc5a0783bcc1640d3ebc5eac950cd9897c26d4bc969718",
  "changes": "Converted from the supplied glTF to a self-contained Godot scene. Original colors and rig/idle/walk animations retained. Scaled and positioned as racing miniatures in-game; no attack animation is used."
}

hearth20/browser/SDK-LICENSE.txt

Copyright (C) Microsoft Corporation. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

   * Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following disclaimer
in the documentation and/or other materials provided with the
distribution.
   * The name of Microsoft Corporation, or the names of its contributors 
may not be used to endorse or promote products derived from this
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

hearth20/browser/SDK-NOTICE.txt

NOTICES AND INFORMATION
Do Not Translate or Localize

This software incorporates material from third parties. Microsoft makes certain
open source code available at https://3rdpartysource.microsoft.com, or you may
send a check or money order for US $5.00, including the product name, the open
source component name, and version number, to:

Source Code Compliance Team
Microsoft Corporation
One Microsoft Way
Redmond, WA 98052
USA

Notwithstanding any other terms, you may reverse engineer this software to the
extent required to debug changes to any libraries licensed under the GNU Lesser
General Public License.

----------------------------------------------------------------

Antlr3.Runtime 3.5.2-rc1 - BSD 3-Clause

[The "BSD license"]
Copyright (c) 2011 The ANTLR Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 3. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

---------------------------------------------------------

---------------------------------------------------------

StringTemplate4 4.0.9-rc1 - BSD 3-Clause

[The "BSD license"]
Copyright (c) 2011 The ANTLR Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 3. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

---------------------------------------------------------


Godot-MIT.txt

Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


Hearthtable-CC0.txt

Creative Commons Legal Code

CC0 1.0 Universal

    CREATIVE COMMONS CORPORATION IS NOT A LAW FIRM AND DOES NOT PROVIDE
    LEGAL SERVICES. DISTRIBUTION OF THIS DOCUMENT DOES NOT CREATE AN
    ATTORNEY-CLIENT RELATIONSHIP. CREATIVE COMMONS PROVIDES THIS
    INFORMATION ON AN "AS-IS" BASIS. CREATIVE COMMONS MAKES NO WARRANTIES
    REGARDING THE USE OF THIS DOCUMENT OR THE INFORMATION OR WORKS
    PROVIDED HEREUNDER, AND DISCLAIMS LIABILITY FOR DAMAGES RESULTING FROM
    THE USE OF THIS DOCUMENT OR THE INFORMATION OR WORKS PROVIDED
    HEREUNDER.

Statement of Purpose

The laws of most jurisdictions throughout the world automatically confer
exclusive Copyright and Related Rights (defined below) upon the creator
and subsequent owner(s) (each and all, an "owner") of an original work of
authorship and/or a database (each, a "Work").

Certain owners wish to permanently relinquish those rights to a Work for
the purpose of contributing to a commons of creative, cultural and
scientific works ("Commons") that the public can reliably and without fear
of later claims of infringement build upon, modify, incorporate in other
works, reuse and redistribute as freely as possible in any form whatsoever
and for any purposes, including without limitation commercial purposes.
These owners may contribute to the Commons to promote the ideal of a free
culture and the further production of creative, cultural and scientific
works, or to gain reputation or greater distribution for their Work in
part through the use and efforts of others.

For these and/or other purposes and motivations, and without any
expectation of additional consideration or compensation, the person
associating CC0 with a Work (the "Affirmer"), to the extent that he or she
is an owner of Copyright and Related Rights in the Work, voluntarily
elects to apply CC0 to the Work and publicly distribute the Work under its
terms, with knowledge of his or her Copyright and Related Rights in the
Work and the meaning and intended legal effect of CC0 on those rights.

1. Copyright and Related Rights. A Work made available under CC0 may be
protected by copyright and related or neighboring rights ("Copyright and
Related Rights"). Copyright and Related Rights include, but are not
limited to, the following:

  i. the right to reproduce, adapt, distribute, perform, display,
     communicate, and translate a Work;
 ii. moral rights retained by the original author(s) and/or performer(s);
iii. publicity and privacy rights pertaining to a person's image or
     likeness depicted in a Work;
 iv. rights protecting against unfair competition in regards to a Work,
     subject to the limitations in paragraph 4(a), below;
  v. rights protecting the extraction, dissemination, use and reuse of data
     in a Work;
 vi. database rights (such as those arising under Directive 96/9/EC of the
     European Parliament and of the Council of 11 March 1996 on the legal
     protection of databases, and under any national implementation
     thereof, including any amended or successor version of such
     directive); and
vii. other similar, equivalent or corresponding rights throughout the
     world based on applicable law or treaty, and any national
     implementations thereof.

2. Waiver. To the greatest extent permitted by, but not in contravention
of, applicable law, Affirmer hereby overtly, fully, permanently,
irrevocably and unconditionally waives, abandons, and surrenders all of
Affirmer's Copyright and Related Rights and associated claims and causes
of action, whether now known or unknown (including existing as well as
future claims and causes of action), in the Work (i) in all territories
worldwide, (ii) for the maximum duration provided by applicable law or
treaty (including future time extensions), (iii) in any current or future
medium and for any number of copies, and (iv) for any purpose whatsoever,
including without limitation commercial, advertising or promotional
purposes (the "Waiver"). Affirmer makes the Waiver for the benefit of each
member of the public at large and to the detriment of Affirmer's heirs and
successors, fully intending that such Waiver shall not be subject to
revocation, rescission, cancellation, termination, or any other legal or
equitable action to disrupt the quiet enjoyment of the Work by the public
as contemplated by Affirmer's express Statement of Purpose.

3. Public License Fallback. Should any part of the Waiver for any reason
be judged legally invalid or ineffective under applicable law, then the
Waiver shall be preserved to the maximum extent permitted taking into
account Affirmer's express Statement of Purpose. In addition, to the
extent the Waiver is so judged Affirmer hereby grants to each affected
person a royalty-free, non transferable, non sublicensable, non exclusive,
irrevocable and unconditional license to exercise Affirmer's Copyright and
Related Rights in the Work (i) in all territories worldwide, (ii) for the
maximum duration provided by applicable law or treaty (including future
time extensions), (iii) in any current or future medium and for any number
of copies, and (iv) for any purpose whatsoever, including without
limitation commercial, advertising or promotional purposes (the
"License"). The License shall be deemed effective as of the date CC0 was
applied by Affirmer to the Work. Should any part of the License for any
reason be judged legally invalid or ineffective under applicable law, such
partial invalidity or ineffectiveness shall not invalidate the remainder
of the License, and in such case Affirmer hereby affirms that he or she
will not (i) exercise any of his or her remaining Copyright and Related
Rights in the Work or (ii) assert any associated claims and causes of
action with respect to the Work, in either case contrary to Affirmer's
express Statement of Purpose.

4. Limitations and Disclaimers.

 a. No trademark or patent rights held by Affirmer are waived, abandoned,
    surrendered, licensed or otherwise affected by this document.
 b. Affirmer offers the Work as-is and makes no representations or
    warranties of any kind concerning the Work, express, implied,
    statutory or otherwise, including without limitation warranties of
    title, merchantability, fitness for a particular purpose, non
    infringement, or the absence of latent or other defects, accuracy, or
    the present or absence of errors, whether or not discoverable, all to
    the greatest extent permissible under applicable law.
 c. Affirmer disclaims responsibility for clearing rights of other persons
    that may apply to the Work or any use thereof, including without
    limitation any person's Copyright and Related Rights in the Work.
    Further, Affirmer disclaims responsibility for obtaining any necessary
    consents, permissions or other rights required for any use of the
    Work.
 d. Affirmer understands and acknowledges that Creative Commons is not a
    party to this document and has no duty or obligation with respect to
    this CC0 or use of the Work.


## Steam networking

GodotSteam GDExtension 4.23.2 — GP Garcia, Chris Ridenour and contributors. MIT license in GodotSteam-LICENSE.txt.
Steamworks SDK redistributable steam_api64.dll, version 1.65, supplied in the official GodotSteam asset. Steam and Steamworks are trademarks of Valve Corporation.
Pinned asset commit: f99b9f54ea64974b8f5288713adc778172e3c60a
Source: https://codeberg.org/godotsteam/godotsteam
Official asset: https://godotengine.org/asset-library/asset/2445
AppID 480 is Valve's shared Spacewar sample identity.


## Steam networking

MIT License

Copyright (c) 2015-Current | GP Garcia, Chris Ridenour, and Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
