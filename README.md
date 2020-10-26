# modelled_stream_crossings

Generate potential locations of road/railway stream crossings and associated structures in British Columbia.

In addition to generating the intersection points of roads/railways and streams, this tool attempts to:

- remove duplicate crossings
- identify crossings that are likely to be bridges/open bottom structures
- maintain a consistent unique identifier value (`modelled_crossing_id`) that is stable with script re-runs

## Methods and sources

### Stream features

Streams are taken from the [BC Freshwater Atlas](https://catalogue.data.gov.bc.ca/dataset/freshwater-atlas-stream-network) and loaded using [fwapg](https://github.com/smnorris/fwapg).

### Linear transportation features

Road and railway features are downloaded from DataBC. Features used to generate stream crossings are defined by the queries below. The queries attempt to extract transportation features only at locations where there is likely to be a stream crossing structure.

| Source         | Query |
| ------------- | ------------- |
| [Digital Road Atlas (DRA)](https://catalogue.data.gov.bc.ca/dataset/digital-road-atlas-dra-master-partially-attributed-roads)  | `transport_line_type_code NOT IN ('F','FP','FR','T','TR','TS','RP','RWA') AND transport_line_surface_code != 'D' AND transport_line_structure_code != 'T' ` |
| [Forest Tenure Roads](https://catalogue.data.gov.bc.ca/dataset/forest-tenure-road-section-lines)  | `life_cycle_status_code NOT IN ('RETIRED', 'PENDING')` |
| [OGC Road Segment Permits](https://catalogue.data.gov.bc.ca/dataset/oil-and-gas-commission-road-segment-permits)  | `status = 'Approved' AND road_type_desc != 'Snow Ice Road'` |
| [OGC Development Roads pre-2006](https://catalogue.data.gov.bc.ca/dataset/ogc-petroleum-development-roads-pre-2006-public-version) | `petrlm_development_road_type != 'WINT'` |
| [NRN Railway Tracks](https://catalogue.data.gov.bc.ca/dataset/railway-track-line)  | `structure_type != 'Tunnel'` (via spatial join to `gba_railway_structure_lines_sp`) |

### Overlay and de-duplication

Intersection points of the stream and road features are created. Because we want to generate locations of individual structures, crossings (on the same stream) are de-duplicated using several data source specific tolerances:

- merge DRA crossings on freeways/highways with a 30m tolerance
- merge DRA crossings on arterial/collector road with a 20m tolerance
- merge other types of DRA crossings within a 12.5m tolerance
- merge FTEN crossings within a 12.5m tolerance
- merge OGC crossings within a 12.5m tolerance
- merge railway crossings within a 20m tolerance

DRA crossings are also merged across streams at a tolerance of 10m.

After same-source data crossings are merged, all crossings are de-duplicated using a 10m tolerance across all (road) data sources (railway crossings are not merged with the road sources). The actual location of an output crossing corresponds to the location from the highest priority dataset - in this order of decreasing priority: DRA, FTEN, OGC permits, OGC permits pre2006. Despite the duplicate removals, the unique identifier for each source road within 10m of a crossing is retained - all crossings can be linked back to their various source road datasets.

### Bridges / Open Bottom Structures

Once duplicates have been removed, output crossings are identified/modelled as open bottom structures via these properties:

| Source         | Query        | output `modelled_crossing_type_source` |
| ------------- | ------------- | ------------- |
| [Stream order](https://catalogue.data.gov.bc.ca/dataset/freshwater-atlas-stream-network) | `stream_order >= 6` | `FWA_STREAM_ORDER` |
| [Rivers/double line streams](https://catalogue.data.gov.bc.ca/dataset/freshwater-atlas-stream-network)  | `edge_type IN (1200, 1250, 1300, 1350, 1400, 1450, 1475)` | `FWA_EDGE_TYPE` |
| [MOT structures](https://catalogue.data.gov.bc.ca/dataset/ministry-of-transportation-mot-road-structures) | `bmis_structure_type = 'BRIDGE'` | `MOT_ROAD_STRUCTURE_SP` |
| [PSCIS structures](https://catalogue.data.gov.bc.ca/dataset/pscis-assessments) | `current_crossing_type_code = 'OBS'` | `PSCIS` |
| [DRA structures](https://catalogue.data.gov.bc.ca/dataset/digital-road-atlas-dra-master-partially-attributed-roads) | `transport_line_structure_code IN ('B','C','E','F','O','R','V')` | `TRANSPORT_LINE_STRUCTURE_CODE` |
| [Railway structures](https://catalogue.data.gov.bc.ca/dataset/railway-structure-line) | `structure_type LIKE 'BRIDGE%'` | `GBA_RAILWAY_STRUCTURE_LINES_SP` |


## Requirements

- a FWA database created by [fwapg](https://github.com/smnorris/fwapg)
- PostgreSQL (requires >= v12)
- PostGIS (tested with v3.0.2)
- GDAL (tested with v3.1.2)
- Python (>=3.6)
- [bcdata](https://github.com/smnorris/bcdata)
- [pscis](https://github.com/smnorris/pscis)
- wget, unzip, parallel


## Installation

The repository is a collection of sql files and shell (bash) scripts - no installation is required.

To get the latest:

    git clone https://github.com/smnorris/modelled_stream_crossings.git
    cd modelled_stream_crossings


## Run the scripts

Scripts presume that environment variables `PGHOST, PGUSER, PGDATABASE, PGPORT, DATABASE_URL` are set to the appropriate db and that password authentication for the database is not required.

If required, download the data:

```
$ ./01_load.sh
```

Run the overlays and produce the outputs:
```
$ ./02_process.sh
```

## Output

Output table is `fish_passage.modelled_stream_crossings`:

```
                                                            Table "fish_passage.modelled_stream_crossings"
            Column             |          Type          | Collation | Nullable |                                       Default
-------------------------------+------------------------+-----------+----------+--------------------------------------------------------------------------------------
 modelled_crossing_id          | integer                |           | not null | nextval('fish_passage.modelled_stream_crossings_modelled_crossing_id_seq'::regclass)
 modelled_crossing_type        | character varying(5)   |           |          |
 modelled_crossing_type_source | text[]                 |           |          |
 transport_line_id             | integer                |           |          |
 ften_road_section_line_id     | text                   |           |          |
 og_road_segment_permit_id     | integer                |           |          |
 og_petrlm_dev_rd_pre06_pub_id | integer                |           |          |
 railway_track_id              | integer                |           |          |
 linear_feature_id             | bigint                 |           |          |
 blue_line_key                 | integer                |           |          |
 downstream_route_measure      | double precision       |           |          |
 wscode_ltree                  | ltree                  |           |          |
 localcode_ltree               | ltree                  |           |          |
 watershed_group_code          | character varying(4)   |           |          |
 geom                          | geometry(PointZM,3005) |           |          |
Indexes:
    "modelled_stream_crossings_pkey" PRIMARY KEY, btree (modelled_crossing_id)
    "modelled_stream_crossings_blue_line_key_idx" btree (blue_line_key)
    "modelled_stream_crossings_ften_road_section_line_id_idx" btree (ften_road_section_line_id)
    "modelled_stream_crossings_geom_idx" gist (geom)
    "modelled_stream_crossings_linear_feature_id_idx" btree (linear_feature_id)
    "modelled_stream_crossings_og_petrlm_dev_rd_pre06_pub_id_idx" btree (og_petrlm_dev_rd_pre06_pub_id)
    "modelled_stream_crossings_og_road_segment_permit_id_idx" btree (og_road_segment_permit_id)
    "modelled_stream_crossings_railway_track_id_idx" btree (railway_track_id)
    "modelled_stream_crossings_transport_line_id_idx" btree (transport_line_id)
```

Also output are several [reports](reports) summarizing crossing counts by various attributes.


## Optional

The script completely re-runs the analysis and new data is created each time it is run - `modelled_crossing_id` will not be consistent between runs.

If retaining existing `modelled_crossing_id` values is required, modify and use the script `sql/09_match_archived_crossings` to match ids against an existing table. Matching is done by finding nearest neighbouring points within 10m.

For published output, this matching script has been run (in a slightly modified form) to match `modelled_crossing_id` to `crossing_id` values from v.2.3.1 of the Fish Passage Technical Working Group model.