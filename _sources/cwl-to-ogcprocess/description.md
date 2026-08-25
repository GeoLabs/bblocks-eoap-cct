This building block provides a comprehensive transformation profile that converts Common Workflow Language (CWL) definitions into OGC API - Processes processDescription schemas. It supports both CommandLineTool and Workflow classes, along with all EOAP custom types.

## Purpose

The CWL to OGC API Processes profile enables:

1. **Automatic conversion**: Transform CWL workflow definitions into OGC-compliant process descriptions
2. **Type mapping**: Map CWL types (including custom types) to JSON Schema format
3. **Metadata preservation**: Maintain documentation, labels, descriptions and the schema.org (or any other prefixed) annotations carried by the CWL document
4. **Standards compliance**: Generate processDescriptions conforming to OGC API - Processes Part 1

## Supported CWL Types

### Standard CWL Types
- Primitive types: `string`, `int`, `long`, `float`, `double`, `boolean`
- File types: `File`, `Directory`, `stdout`, `stderr`
- Array types, in both the short (`string[]`) and long (`{type: array, items: ...}`) form
- Enumerations (`{type: enum, symbols: [...]}`), mapped to a JSON Schema `enum`
- Optional types (`string?`, `["null", "string"]`), which set `minOccurs: 0`
- Unions of several non-null types, mapped to a JSON Schema `oneOf`

An output of type `Directory` is the EOAP stage-out result and is therefore mapped
to a **STAC Collection** schema rather than to an opaque directory reference.

### EOAP Custom Types

#### BBox Types
- `bbox.yaml#BBox` - 2D bounding box
- `bbox.yaml#BBox3D` - 3D bounding box with elevation
- Maps to OGC bbox schema with CRS support

#### GeoJSON Types
- `geojson.yaml#Point` - GeoJSON Point geometry
- `geojson.yaml#Feature` - GeoJSON Feature
- `geojson.yaml#FeatureCollection` - GeoJSON FeatureCollection
- Maps to GeoJSON format with appropriate schemas

#### STAC Types
- `stac.yaml#Item` - STAC Item
- `stac.yaml#Collection` - STAC Collection
- `stac.yaml#Catalog` - STAC Catalog
- Maps to STAC format specifications

#### String Format Types
- `string-format.yaml#DateTime` - ISO 8601 date-time
- `string-format.yaml#Date` - ISO 8601 date
- `string-format.yaml#Time` - Time of day
- `string-format.yaml#Duration` - ISO 8601 duration
- `string-format.yaml#URI` - Uniform Resource Identifier
- `string-format.yaml#Email` - Email address
- `string-format.yaml#UUID` - Universally Unique Identifier
- `string-format.yaml#IPv4` - IPv4 address
- `string-format.yaml#IPv6` - IPv6 address
- `string-format.yaml#Hostname` - DNS hostname

## Transformation Process

The transformation follows these steps:

1. **Extract root element**: Handle both direct CWL documents and those with `$graph` structure
2. **Process metadata**: Extract id, title, description from CWL document
3. **Preserve annotations**: Convert every prefixed annotation into an OGC `metadata` entry
4. **Map inputs**: Convert CWL inputs to OGC process inputs with appropriate schemas
5. **Map outputs**: Convert CWL outputs to OGC process outputs with appropriate schemas
6. **Add execution options**: Include jobControlOptions and outputTransmission modes

## Execution and deployment

A CWL process reaches the server through OGC API - Processes Part 2
(Deploy, Replace, Undeploy), which fixes two members regardless of the CWL content:

- `mutable: true` — the process was deployed, so it can be replaced and undeployed
- `jobControlOptions: ["async-execute"]` — a deployed CWL process cannot be run
  synchronously, so no other execution mode is advertised

## Annotation preservation

Any key carrying a prefix declared in `$namespaces` — `s:author`, `s:license`,
`dct:rightsHolder`, … — is preserved as an OGC API - Processes `metadata` entry
whose `role` is the fully expanded IRI of the term. Annotations are collected both
from the document root and from the root `Workflow`; when the same term appears in
both, the `Workflow`-level one wins.

Values are normalised to plain JSON-LD: `class: s:Person` becomes
`"@type": "Person"` with `"@context": "https://schema.org"`, and prefixed member
names are reduced to their local part, recursively. A list-valued annotation
(two `s:author` entries, say) yields one `metadata` entry per element.

```json
{
  "role": "https://schema.org/author",
  "value": {
    "@context": "https://schema.org",
    "@type": "Person",
    "name": "Gérald Fenoy",
    "identifier": "https://orcid.org/0000-0002-9617-8641"
  }
}
```

Three terms are handled specially rather than as generic metadata:

| CWL annotation | OGC API - Processes member |
| --- | --- |
| `s:softwareVersion`, falling back to `s:version` | `version` |
| `s:keywords` (YAML list or comma-separated string) | `keywords` |
| `label` / `doc` of the root element | `title` / `description`, mirrored as the `schema.org/name` and `schema.org/description` roles unless the CWL declares them |

