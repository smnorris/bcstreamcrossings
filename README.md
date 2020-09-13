# modelled_stream_crossings

Generate potential locations of road/railway stream crossings and associated structures in British Columbia.

In addition to generating the intersection points of roads/railways and streams, this tool attempts to:

- remove duplicate crossings
- identify crossings that are likely to be bridges/open bottom structures
- maintain a consistent unique identifier value (`modelled_crossing_id`) that is stable with script re-runs

## Data sources

### Transportation features

All road and railway features as defined by these queries are used to generate stream crossings - the queries attempt to extract only transportation features at which there is likely to be a stream crossing structure.

| Source         | Query |
| ------------- | ------------- |
| [Digital Road Atlas (DRA)](https://catalogue.data.gov.bc.ca/dataset/digital-road-atlas-dra-master-partially-attributed-roads)  | `transport_line_type_code NOT IN ('F','FP','FR','T','TD','TR','TS','RP','RWA') AND transport_line_surface_code NOT IN ('D') AND COALESCE(transport_line_structure_code, '') != 'T' ` |
| [Forest Tenure Roads](https://catalogue.data.gov.bc.ca/dataset/forest-tenure-road-section-lines)  | `life_cycle_status_code NOT IN ('RETIRED', 'PENDING')` |
| [OGC Road Segment Permits](https://catalogue.data.gov.bc.ca/dataset/oil-and-gas-commission-road-segment-permits)  | `status = 'Approved' AND road_type_desc != 'Snow Ice Road'` |
| [OGC Development Roads pre-2006](https://catalogue.data.gov.bc.ca/dataset/ogc-petroleum-development-roads-pre-2006-public-version) | `petrlm_development_road_type != 'WINT'` |
| [NRN Railway Tracks](https://catalogue.data.gov.bc.ca/dataset/railway-track-line)  | `structure_type != 'Tunnel'` (via spatial join to `gba_railway_structure_lines_sp`) |

### Stream features

Streams are from the [BC Freshwater Atlas](https://catalogue.data.gov.bc.ca/dataset/freshwater-atlas-stream-network)

## Requirements

- a FWA database created by [fwapg](https://github.com/smnorris/fwapg)
- PostgreSQL (requires >= v12)
- PostGIS (tested with >=v3.0.1)
- GDAL (tested with >= v2.4.4)
- Python (>=3.6)
- [bcdata](https://github.com/smnorris/bcdata)
- [pscis](https://github.com/smnorris/pscis)
- wget, unzip


## Installation

The repository is a collection of sql files and shell scripts - no installation is required.

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

## Outputs

Output table is `fish_passage.modelled_stream_crossings`:

```
                                                            Table "fish_passage.modelled_stream_crossings"
            Column             |          Type          | Collation | Nullable |                                       Default
-------------------------------+------------------------+-----------+----------+--------------------------------------------------------------------------------------
 modelled_crossing_id          | integer                |           | not null | nextval('fish_passage.modelled_stream_crossings_modelled_crossing_id_seq'::regclass)
 transport_line_id             | integer                |           |          |
 ften_road_segment_id          | text                   |           |          |
 og_road_segment_permit_id     | integer                |           |          |
 og_petrlm_dev_rd_pre06_pub_id | integer                |           |          |
 railway_track_id              | integer                |           |          |
 linear_feature_id             | bigint                 |           |          |
 blue_line_key                 | integer                |           |          |
 downstream_route_measure      | double precision       |           |          |
 wscode_ltree                  | ltree                  |           |          |
 localcode_ltree               | ltree                  |           |          |
 watershed_group_code          | character varying(4)   |           |          |
 modelled_crossing_type        | character varying(5)   |           |          |
 modelled_crossing_type_source | text[]                 |           |          |
 geom                          | geometry(PointZM,3005) |           |          |
Indexes:
    "modelled_stream_crossings_pkey" PRIMARY KEY, btree (modelled_crossing_id)
    "modelled_stream_crossings_blue_line_key_idx" btree (blue_line_key)
    "modelled_stream_crossings_ften_road_segment_id_idx" btree (ften_road_segment_id)
    "modelled_stream_crossings_geom_idx" gist (geom)
    "modelled_stream_crossings_linear_feature_id_idx" btree (linear_feature_id)
    "modelled_stream_crossings_og_petrlm_dev_rd_pre06_pub_id_idx" btree (og_petrlm_dev_rd_pre06_pub_id)
    "modelled_stream_crossings_og_road_segment_permit_id_idx" btree (og_road_segment_permit_id)
    "modelled_stream_crossings_railway_track_id_idx" btree (railway_track_id)
    "modelled_stream_crossings_transport_line_id_idx" btree (transport_line_id)
```

Also output is [`modelled_stream_crossing_summary.csv`](modelled_stream_crossing_summary.csv), listing number of crossings per watershed group by crossing type and source.
