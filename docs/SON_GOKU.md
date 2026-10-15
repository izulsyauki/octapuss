# Son Goku role matching and manual assignment

The supplied `cursor-example/son-goku` folder uses filenames such as `goku - normal.ani`, `goku - text .ani`, and `goku - d1.ani`. Earlier detection required the entire normalized filename to be a role, so the theme prefix left these files unassigned.

Detection now checks the complete filename first, then an exact role suffix following a spaced ` - ` separator. Short resize names `horizontal`, `vertical`, `d1` (NW–SE), and `d2` (NE–SW) are recognized. Arbitrary words inside filenames do not trigger matching. Unknown names remain unassigned rather than guessed. Folder import reads the 15 ANI files; the accompanying `.crs` metadata is not imported or executed.

Manual mapping is independent of filename detection: select any imported cursor tile and choose **Use for** above the gallery. Supported roles apply through **Apply pack**. **Unassigned** explicitly excludes a file. Manual choices are saved atomically, override detected/native roles, and survive relaunch and matching-folder updates. Duplicate overlapping roles block Apply. Handwriting and alternate-select remain labeled as lacking a global macOS equivalent; users can assign their artwork to another supported role.

Safe checks passed all 15 supplied files, 13 mapped roles, and 56 planned slots, plus explicit reassignment, exclusion, persistence, and folder reimport. Negative checks reject role-like words inside unrelated names. Run `OCTAPUSS_GOKU_FIXTURE_PATH=/absolute/path/son-goku rtk proxy zsh scripts/build-phase0.sh --check` to include the fixture checks. The original artwork remains local, untracked input and is not bundled with Octapuss.

Real integration passed Apply/Restore for all 56 slots, verifying baseline pixels, dimensions, hotspots, and journal removal. SIGKILL of an owned test worker also restored every slot. The updated app recognized the user's existing Son Goku set without reimporting it. UI automation manually excluded the text cursor with **Unassigned**, then saved **Text select** again and applied the pack. The final app reports **System pack: son-goku · 13 roles** and **56 system slots** at the selected Large size. Full Xcode/XCTest, other OS/hardware versions, and visual observation of every external cursor context remain untested.

## Blank Busy and Working artwork

The supplied Busy and Working ANI files contain uncompressed 8-bit DIB frames with short palettes: 14 and 16 RGBQUAD entries respectively. ImageIO's ICO decoding path misread these payloads, yielding fully transparent PNGs for every sequence step. The role mapping was valid, but both gallery images and animation artwork were invisible.

Before ImageIO decoding, Octapuss now expands unused entries in these short 8-bit palettes to a complete 256-color table and updates the container metadata. Existing pixel indices, colors, AND transparency mask, hotspot, sequence, and timing stay intact. Only bounded, uncompressed 40-byte-header DIBs with an explicit short palette use this normalization. Other encodings retain their existing path.

A synthetic short-palette regression failed before the fix and now verifies opaque artwork alongside a transparent masked pixel. Fixture checks verify visible pixels in all 27 Busy and 10 Working sequence frames. Corrected first-frame PNGs were visually inspected. Previously imported transparent copies must be refreshed by importing the same original folder again; matching sets keep their IDs and manual assignments. Source files are not modified.

After the palette correction, the full 56-slot normal restoration and owned-worker SIGKILL recovery checks passed again. The user's saved set was refreshed through the native folder-import panel; its Busy and Working PNGs now have alpha spanning 0–255, and the manual Text role override remains `text`. Initial UI recapture was interrupted by automation connection failures. After reconnecting, on-screen inspection confirmed visible artwork in both gallery tiles and the enlarged Working preview. Applying the refreshed pack reported **System pack: son-goku · 13 roles** and **56 system slots**. Visual observation of every external cursor context remains untested.
