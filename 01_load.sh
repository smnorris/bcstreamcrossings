#!/bin/bash
set -euxo pipefail

# Get road data and load to postgres

# This script presumes:
# 1. The PGHOST, PGUSER, PGDATABASE, PGPORT environment variables are set
# 2. Password authentication for the DB is not required


# Directly download the DRA archive, it is too big to reliably request via WFS
# *** NOTE ***
# Structure of data in this archive DO NOT MATCH structure in the BCGW !
# To avoid this issue, load data to whse_basemapping.transport_line rather than DRA_DGTL_ROAD_ATLAS_MPAR_SP
# ************
wget -N ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/DRA_Public/dgtl_road_atlas.gdb.zip
unzip -qun dgtl_road_atlas.gdb.zip

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -overwrite \
  -lco GEOMETRY_NAME=geom \
  -lco FID=transport_line_id \
  -nln whse_basemapping.transport_line \
  dgtl_road_atlas.gdb \
  transport_line

# get additional data direct from BCGW. Note the ALLCAPS for the requests
# just request everything and run subset queries in the crossing generation script
bcdata bc2pg WHSE_FOREST_TENURE.FTEN_ROAD_SEGMENT_LINES_SVW # this table doesn't have a single primary key
bcdata bc2pg WHSE_MINERAL_TENURE.OG_ROAD_SEGMENT_PERMIT_SP --fid og_road_segment_permit_id
bcdata bc2pg WHSE_MINERAL_TENURE.OG_PETRLM_DEV_RDS_PRE06_PUB_SP --fid og_petrlm_dev_rd_pre06_pub_id
bcdata bc2pg WHSE_BASEMAPPING.GBA_RAILWAY_TRACKS_SP --fid railway_track_id