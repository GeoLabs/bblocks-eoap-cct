# Unified transform: CWL CommandLineTool/Workflow to OGC API Processes processDescription
# Uses reference schemas (allOf + $ref) for EOAP custom types: BBox, GeoJSON, STAC
# Preserves the CWL annotations (schema.org and any other declared $namespaces prefix)
# as OGC API - Processes `metadata` entries, plus `keywords` and `version`.

# Helper function to extract the root element (first Workflow in $graph, or the document itself)
def getRootElement:
  if has("$graph") then
    # Find the first Workflow in the $graph array
    (."$graph" | map(select(.class == "Workflow")) | first) // ."$graph"[0]
  else
    .
  end;

# --- Namespace / annotation helpers -----------------------------------------

# Prefix declared in $namespaces that matches this key ("s:author" -> "s"), or null
def matchedPrefix($ns):
  . as $k |
  ($ns | keys | map(select(. as $p | $k | startswith($p + ":"))) | first);

# Local part of a prefixed key ("s:author" -> "author"); unprefixed keys are returned as-is
def localName($ns):
  . as $k |
  ($k | matchedPrefix($ns)) as $p |
  if $p then $k[($p | length) + 1:] else $k end;

# Fully expanded IRI of a prefixed key ("s:author" -> "https://schema.org/author"),
# or null when the key carries no declared prefix (structural CWL keys, $graph, ...)
def termIRI($ns):
  . as $k |
  ($k | matchedPrefix($ns)) as $p |
  if $p then ($ns[$p] + $k[($p | length) + 1:]) else null end;

# Recursively turn a CWL annotation value into plain JSON-LD:
#   { class: "s:Person", "s:name": "..." }
#     -> { "@context": "https://schema.org", "@type": "Person", "name": "..." }
def normalizeJsonLd($ns):
  if type == "object" then
    (.class // null) as $cls |
    (if ($cls | type) == "string" then ($cls | matchedPrefix($ns)) else null end) as $clsPrefix |
    (if $clsPrefix then
       { "@context": ($ns[$clsPrefix] | sub("/$"; "")),
         "@type": $cls[($clsPrefix | length) + 1:] }
     elif ($cls | type) == "string" then
       { "@type": $cls }
     else
       {}
     end)
    + ( to_entries
        | map(select(.key != "class"))
        | map({ key: (.key | localName($ns)), value: (.value | normalizeJsonLd($ns)) })
        | from_entries )
  elif type == "array" then
    map(normalizeJsonLd($ns))
  else
    .
  end;

# All prefixed annotations of an object as OGC `metadata` entries.
# `keywords` is excluded: it is surfaced as the top-level `keywords` member instead.
# List-valued annotations (s:author with two people) yield one entry per element.
def collectAnnotations($ns):
  if type == "object" then
    [ to_entries[]
      | select((.key | termIRI($ns)) != null)
      | select((.key | localName($ns)) != "keywords")
      | (.key | termIRI($ns)) as $role
      | (if (.value | type) == "array" then .value else [.value] end)
      | .[]
      | { role: $role, value: normalizeJsonLd($ns) }
    ]
  else
    []
  end;

# Value of a single annotation, by local name ("softwareVersion"), or null
def annotationValue($ns; $name):
  if type == "object" then
    [ to_entries[]
      | select((.key | termIRI($ns)) != null)
      | select((.key | localName($ns)) == $name)
      | .value ] | first
  else
    null
  end;

# Keywords, accepting both a YAML list and a comma-separated string
def collectKeywords($ns):
  (annotationValue($ns; "keywords")) as $kw |
  if $kw == null then []
  elif ($kw | type) == "array" then ($kw | map(tostring))
  elif ($kw | type) == "string" then
    ($kw | split(",") | map(sub("^\\s+"; "") | sub("\\s+$"; "")) | map(select(length > 0)))
  else [ $kw | tostring ]
  end;

# Order-preserving deduplication
def dedup: reduce .[] as $x ([]; if (index($x) != null) then . else . + [$x] end);

# --- Type mapping ------------------------------------------------------------

# Map BBox custom type to OGC schema with reference
def mapBBoxType:
  if (. | type) == "string" and ((. | contains("bbox.yaml#BBox")) or (. | contains("ogc.yaml#BBox"))) then
    {
      allOf: [
        {
          format: "ogc-bbox"
        },
        {
          "$ref": "https://raw.githubusercontent.com/opengeospatial/ogcapi-processes/master/openapi/schemas/processes-core/bbox.yaml"
        }
      ]
    }
  else
    null
  end;

# Map GeoJSON custom types to OGC schemas with references
def mapGeoJSONType:
  if (. | type) == "string" then
    if (. | contains("geojson.yaml#")) then
      if (. | contains("Point")) then
        {
          allOf: [
            {
              format: "geojson-geometry"
            },
            {
              "$ref": "https://geojson.org/schema/Point.json"
            }
          ]
        }
      elif (. | contains("FeatureCollection")) then
        {
          allOf: [
            {
              format: "geojson-feature-collection"
            },
            {
              "$ref": "https://geojson.org/schema/FeatureCollection.json"
            }
          ]
        }
      elif (. | contains("Feature")) then
        {
          allOf: [
            {
              format: "geojson-feature"
            },
            {
              "$ref": "https://geojson.org/schema/Feature.json"
            }
          ]
        }
      elif (. | contains("Polygon")) then
        {
          allOf: [
            {
              format: "geojson-geometry"
            },
            {
              "$ref": "https://geojson.org/schema/Polygon.json"
            }
          ]
        }
      else
        {
          allOf: [
            {
              format: "geojson-geometry"
            },
            {
              "$ref": "https://geojson.org/schema/Geometry.json"
            }
          ]
        }
      end
    else
      null
    end
  else
    null
  end;

# STAC Collection schema, reused for the EOAP stage-out Directory output
def stacCollectionSchema:
  {
    allOf: [
      {
        format: "stac-collection"
      },
      {
        "$ref": "https://raw.githubusercontent.com/radiantearth/stac-api-spec/refs/heads/release/v1.0.0/stac-spec/collection-spec/json-schema/collection.json"
      }
    ]
  };

# Map STAC custom types to OGC schemas with references
def mapSTACType:
  if (. | type) == "string" and (. | contains("stac.yaml#")) then
    if (. | contains("Item")) then
      {
        allOf: [
          {
            format: "stac-item"
          },
          {
            "$ref": "https://raw.githubusercontent.com/radiantearth/stac-api-spec/refs/heads/release/v1.0.0/stac-spec/item-spec/json-schema/item.json"
          }
        ]
      }
    elif (. | contains("Collection")) then
      stacCollectionSchema
    elif (. | contains("Catalog")) then
      {
        allOf: [
          {
            format: "stac-catalog"
          },
          {
            "$ref": "https://raw.githubusercontent.com/radiantearth/stac-api-spec/refs/heads/release/v1.0.0/stac-spec/catalog-spec/json-schema/catalog.json"
          }
        ]
      }
    else
      {
        allOf: [
          {
            format: "stac"
          },
          {
            "$ref": "https://raw.githubusercontent.com/radiantearth/stac-api-spec/refs/heads/release/v1.0.0/stac-spec/catalog-spec/json-schema/catalog.json"
          }
        ]
      }
    end
  else
    null
  end;

# Map string format custom types to OGC schemas
def mapStringFormatType:
  if (. | type) == "string" and (. | contains("string-format.yaml#")) then
    if (. | contains("DateTime")) then
      { type: "string", format: "date-time" }
    elif (. | contains("Date")) then
      { type: "string", format: "date" }
    elif (. | contains("Time")) then
      { type: "string", format: "time" }
    elif (. | contains("Duration")) then
      { type: "string", format: "duration" }
    elif (. | contains("URI")) then
      { type: "string", format: "uri" }
    elif (. | contains("Email")) then
      { type: "string", format: "email" }
    elif (. | contains("UUID")) then
      { type: "string", format: "uuid" }
    elif (. | contains("IPv4")) then
      { type: "string", format: "ipv4" }
    elif (. | contains("IPv6")) then
      { type: "string", format: "ipv6" }
    elif (. | contains("Hostname")) then
      { type: "string", format: "hostname" }
    else
      { type: "string" }
    end
  else
    null
  end;

# Map CWL File type to OGC schema
def mapFileType:
  if . == "File" or . == "stdout" or . == "stderr" then
    {
      type: "string",
      contentMediaType: "application/octet-stream"
    }
  else
    null
  end;

# Map CWL Directory type to OGC schema
def mapDirectoryType:
  if . == "Directory" then
    {
      type: "string",
      contentMediaType: "application/x-directory"
    }
  else
    null
  end;

# Strip the optional marker and the null branch of a union type:
#   "string?"          -> "string"
#   ["null", "string"] -> "string"
def normalizeTypeSpec:
  if type == "string" then
    (if endswith("?") then .[0:-1] else . end)
  elif type == "array" then
    (map(select(. != "null"))) as $t |
    (if ($t | length) == 1 then $t[0] else $t end)
  else
    .
  end;

# True when the declared type accepts null (i.e. the parameter is optional)
def isOptionalType:
  if type == "string" then endswith("?")
  elif type == "array" then any(.[]; . == "null")
  else false
  end;

# Unified type mapper. $stageOut selects the EOAP convention where a Directory
# output is the stage-out STAC Collection rather than an opaque directory.
def mapTypeCtx($stageOut):
  normalizeTypeSpec as $t |
  if ($t | type) == "string" then
    if ($t | endswith("[]")) then
      { type: "array", items: ($t[0:-2] | mapTypeCtx($stageOut)) }
    elif $stageOut and $t == "Directory" then
      stacCollectionSchema
    else
      ($t | mapBBoxType) // ($t | mapGeoJSONType) // ($t | mapSTACType)
        // ($t | mapStringFormatType) // ($t | mapFileType) // ($t | mapDirectoryType)
        // (if $t == "string" then { type: "string" }
            elif $t == "int" or $t == "long" then { type: "integer" }
            elif $t == "float" or $t == "double" then { type: "number" }
            elif $t == "boolean" then { type: "boolean" }
            else { type: "string" }
            end)
    end
  elif ($t | type) == "array" then
    # Union of several non-null types
    { oneOf: ($t | map(mapTypeCtx($stageOut))) }
  elif ($t | type) == "object" then
    if $t.type == "array" then
      { type: "array", items: ($t.items | mapTypeCtx($stageOut)) }
    elif $t.type == "enum" then
      { type: "string", enum: ($t.symbols | map(sub(".*[#/]"; ""))) }
    elif ($t | has("type")) then
      ($t.type | mapTypeCtx($stageOut))
    else
      { type: "object" }
    end
  else
    { type: "object" }
  end;

def mapType: mapTypeCtx(false);
def mapOutputType: mapTypeCtx(true);

# --- Input / output descriptions --------------------------------------------

# Build one OGC input description from a CWL input parameter object
def inputDescription($id):
  . as $param |
  ($param.type) as $t |
  {
    title: ($param.label // $id),
    description: ($param.doc // ""),
    schema: (($t | mapType) + (if ($param | has("default")) then { default: $param.default } else {} end)),
    minOccurs: (if ($t | isOptionalType) or ($param | has("default")) then 0 else 1 end),
    maxOccurs: 1
  };

# Build one OGC output description from a CWL output parameter object
def outputDescription($id):
  . as $param |
  {
    title: ($param.label // $id),
    description: ($param.doc // ""),
    schema: ($param.type | mapOutputType)
  };

# Process inputs
def processInputs:
  if . then
    if (. | type) == "array" then
      # Workflow style: inputs is an array with id fields
      map(.id as $id | { key: $id, value: inputDescription($id) }) | from_entries
    else
      # CommandLineTool style: inputs is an object
      to_entries | map(.key as $id | { key: $id, value: (.value | inputDescription($id)) }) | from_entries
    end
  else
    {}
  end;

# Process outputs
def processOutputs:
  if . then
    if (. | type) == "array" then
      # Workflow style: outputs is an array with id fields
      map(.id as $id | { key: $id, value: outputDescription($id) }) | from_entries
    else
      # CommandLineTool style: outputs is an object
      to_entries | map(.key as $id | { key: $id, value: (.value | outputDescription($id)) }) | from_entries
    end
  else
    {}
  end;

# --- Main transformation -----------------------------------------------------

. as $doc |
(($doc["$namespaces"] // {})) as $ns |
getRootElement as $root |

($root | collectAnnotations($ns)) as $rootMeta |
($doc | collectAnnotations($ns)) as $docMeta |
# Workflow-level annotations win over document-level ones for the same role
($rootMeta + ($docMeta | map(select(.role as $r | ($rootMeta | map(.role) | index($r)) == null)))) as $declaredMeta |

(($root | collectKeywords($ns)) + ($doc | collectKeywords($ns)) | dedup) as $keywords |

(($root | annotationValue($ns; "softwareVersion"))
  // ($root | annotationValue($ns; "version"))
  // ($doc | annotationValue($ns; "softwareVersion"))
  // ($doc | annotationValue($ns; "version"))
  // "1.0.0") as $version |

($root.id // (if ($root.baseCommand | type) == "array" then $root.baseCommand[0] else $root.baseCommand end) // "cwl-process") as $id |
($root.label // $root.id // "CWL Process") as $title |
($root.doc // "Process converted from CWL") as $description |

# Mirror the core descriptive members as schema.org metadata, unless the CWL
# already declared them explicitly
($declaredMeta | map(.role)) as $declaredRoles |
([ { role: "https://schema.org/name", value: $title },
   { role: "https://schema.org/description", value: $description } ]
  + (if ($declaredRoles | index("https://schema.org/version")) == null
     then [ { role: "https://schema.org/softwareVersion", value: $version } ] else [] end)
  | map(select(.role as $r | ($declaredRoles | index($r)) == null))) as $derivedMeta |

{
  id: $id,
  version: ($version | tostring),
  title: $title,
  description: $description,
  # A CWL process is deployed through OGC API - Processes Part 2, hence replaceable/removable
  mutable: true
}
+ (if ($keywords | length) > 0 then { keywords: $keywords } else {} end)
+ { metadata: ($derivedMeta + $declaredMeta) }
+ {
  inputs: ($root.inputs | processInputs),
  outputs: ($root.outputs | processOutputs),

  # A deployed CWL process can only be executed asynchronously
  jobControlOptions: ["async-execute"],
  outputTransmission: ["value", "reference"]
}
