# EOAP CWL Custom Types Building Blocks

Building Blocks for CWL Custom Types used in Earth Observation Application Packages (EOAP).
These types enable mapping between CWL workflow inputs/outputs and OGC API Processes descriptions.


The custom types provide a standardized way to describe:
- GeoJSON geometries and features for spatial inputs/outputs
- STAC Catalogs, Collections, and Items for EO data manifests
- OGC bounding boxes for spatial extents
- Standard string formats (datetime, URI, email, etc.)

These types bridge the gap between CWL workflow specifications and OGC API Processes
processDescription schemas, enabling automatic mapping of inputs and outputs as described
in Table 13 of OGC API - Processes Part 1: Core ([OGC 18-062r3](https://docs.ogc.org/DRAFTS/18-062r3.html)).

**Note**: These building blocks document CWL Custom Types defined in [eoap/schemas](https://github.com/eoap/schemas). 
The JSON Schemas provided are translations for documentation purposes. CWL uses Schema Salad as its schema 
language, which is based on Apache Avro Schema and extends it with semantic annotations for linked data.


## Building Blocks

### `eoap.cct.bbox` — eaop-cct:OGC-BoundingBox

**Type:** schema

CWL custom type for OGC bounding box with coordinate reference system

### `eoap.cct.string-format` — eaop-cct:String-Format

**Type:** schema

CWL custom types for standard string formats (date, datetime, URI, email, etc.)

### `eoap.cct.geojson` — eaop-cct:GeoJSON

**Type:** schema

CWL custom types for GeoJSON geometries, features, and feature collections

### `eoap.cct.stac` — eaop-cct:STAC

**Type:** schema

CWL custom types for STAC Catalogs, Items, and Collections

### `eoap.cct.cwl-to-ogcprocess` — CWL to OGC API Processes Profile

**Type:** model

Profile for converting CWL CommandLineTool and Workflow definitions to OGC API Processes processDescriptions

