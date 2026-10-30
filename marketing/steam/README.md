# Steam marketing package

The `capsules/` directory contains the four required Steam store capsule sizes, Steam Library artwork, and app icons. `screenshots/` contains five unaltered 1920×1080 captures from the running Godot game. `trailer/last_call_gameplay_teaser.mp4` is an 18-second H.264/AAC teaser: 15 seconds of in-engine footage followed by a key art end card. `STORE_COPY.md` holds English and Arabic page text and the recommended upload order.

The two images in `source/` are marketing key art, separate from gameplay screenshots. They were generated for this project and can be revised without changing game art. The Godot captures show the current playable build, including the present field-map lighting.

To recapture a screenshot, run Godot in windowed mode with `res://tools/marketing/capture_store.tscn -- <preset>`. Presets include `station`, `cad`, `vsa`, `farmhouse`, and `highway`. Prefix a preset with `clip_` to capture 72 trailer frames into `trailer/frames/<preset>/`. Then run `python tools/marketing/build_capsules.py` and `python tools/marketing/build_trailer.py --ffmpeg <ffmpeg executable>`. `build_trailer.py` needs Pillow and an ffmpeg build with `h264_nvenc` and `aac` encoders; captured frame directories are intermediate files and are not part of the published package.

Dimensions were checked against [Steam's graphical asset documentation](https://partner.steamgames.com/doc/store/assets). Screenshots are actual gameplay images, per [Steam's screenshot guidance](https://partner.steamgames.com/doc/store/assets/standard). The video uses [Steam's recommended 1920×1080, 30 fps H.264/AAC format](https://partner.steamgames.com/doc/store/trailer).
