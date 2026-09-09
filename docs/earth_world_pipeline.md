# Earth World Pipeline

THE MULTIVERSE uses real-world geographic layout as a starting point while keeping the final game art original.

## Data flow

1. Obtain an open geographic extract (OpenStreetMap/compatible open data).
2. Convert the extract offline into normalized JSON.
3. `earth_region_importer.gd` validates and reads the normalized region.
4. Roads, building footprints, parks, water and other layers become world-layout inputs.
5. `city_builder.gd` adds original procedural buildings, streets, vegetation and visual dressing.
6. Region streaming loads only the area around the player.
7. Later passes replace selected procedural structures with handcrafted original assets.

## Normalized region format

```json
{
  "roads": [{"points": [[0,0],[40,0]], "class": "primary"}],
  "buildings": [{"polygon": [[0,0],[10,0],[10,8],[0,8]], "height": 30}],
  "water": [{"polygon": [[-100,-100],[100,-100],[100,-20],[-100,-20]]}],
  "parks": [{"polygon": [[20,20],[60,20],[60,60],[20,60]]}]
}
```

## Licensing

When OpenStreetMap data is used, include appropriate attribution and comply with the OpenStreetMap ODbL. Do not import Google Maps/Earth tiles, satellite imagery, or copied Google building geometry into the repository.

## Visual target

Geographic accuracy supplies the skeleton. Original materials, procedural architecture, vegetation, traffic, lighting, VFX, destruction and landmarks supply the game's visual identity.
