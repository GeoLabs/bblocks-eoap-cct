# Unified transform: CWL CommandLineTool/Workflow to OGC API Processes processDescription
# Supports all EOAP custom types: BBox, GeoJSON, STAC, and String Formats
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

# Map BBox custom type to OGC schema
def mapBBoxType:
  if (. | type) == "string" and ((. | contains("bbox.yaml#BBox")) or (. | contains("ogc.yaml#BBox"))) then
    {
      type: "object",
      required: ["bbox"],
      properties: {
        bbox: {
          type: "array",
          items: { type: "number" },
          oneOf: [
            { minItems: 4, maxItems: 4, description: "2D bbox" },
            { minItems: 6, maxItems: 6, description: "3D bbox" }
          ]
        },
        crs: {
          type: "string",
          enum: ["CRS84", "CRS84h"],
          default: "CRS84"
        }
      }
    }
  else
    null
  end;

# Map GeoJSON custom types to OGC schemas
def mapGeoJSONType:
  if (. | type) == "string" then
    if (. | contains("geojson.yaml#")) then
      if (. | contains("Point")) then
        {
          type: "object",
          required: ["type", "coordinates"],
          properties: {
            type: { type: "string", enum: ["Point"] },
            coordinates: {
              type: "array",
              minItems: 2,
              maxItems: 3,
              items: { type: "number" }
            }
          },
          format: "geojson-geometry"
        }
      elif (. | contains("FeatureCollection")) then
        {
          type: "object",
          required: ["type", "features"],
          properties: {
            type: { type: "string", enum: ["FeatureCollection"] },
            features: {
              type: "array",
              items: { type: "object" }
            }
          },
          format: "geojson-feature-collection"
        }
      elif (. | contains("Feature")) then
        {
          type: "object",
          required: ["type", "geometry", "properties"],
          properties: {
            type: { type: "string", enum: ["Feature"] },
            geometry: { type: "object" },
            properties: { type: "object" }
          },
          format: "geojson-feature"
        }
      else
        { type: "object", format: "geojson-geometry" }
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
    type: "object",
    required: ["type", "stac_version", "id", "description", "license", "extent", "links"],
    properties: {
      type: { type: "string", enum: ["Collection"] },
      stac_version: { type: "string" },
      id: { type: "string" },
      title: { type: "string" },
      description: { type: "string" },
      license: { type: "string" },
      extent: { type: "object" },
      links: { type: "array" },
      assets: { type: "object" }
    },
    format: "stac-collection"
  };

# Map STAC custom types to OGC schemas
def mapSTACType:
  if (. | type) == "string" and (. | contains("stac.yaml#")) then
    if (. | contains("Item")) then
      {
        type: "object",
        required: ["type", "stac_version", "id", "geometry", "properties", "links", "assets"],
        properties: {
          type: { type: "string", enum: ["Feature"] },
          stac_version: { type: "string" },
          id: { type: "string" },
          geometry: { type: "object" },
          properties: { type: "object" },
          links: { type: "array" },
          assets: { type: "object" }
        },
        format: "stac-item"
      }
    elif (. | contains("Collection")) then
      stacCollectionSchema
    elif (. | contains("Catalog")) then
      {
        type: "object",
        required: ["type", "stac_version", "id", "description", "links"],
        properties: {
          type: { type: "string", enum: ["Catalog"] },
          stac_version: { type: "string" },
          id: { type: "string" },
          title: { type: "string" },
          description: { type: "string" },
          links: { type: "array" }
        },
        format: "stac-catalog"
      }
    else
      { type: "object", format: "stac" }
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

# --- CWL `format` -> OGC API - Processes media type (M-01/M-02) ------------
#
# CWL declares acceptable media types for a File/Directory input or output as
# a sibling `format:` field (a single IRI, or a list of IRIs when more than
# one is accepted), not as part of `type`. The type mapper above never sees
# it, by design (it only ever receives the bare type expression, so it can
# recurse cleanly through `?`, arrays and unions). These helpers resolve
# `format` separately and `applyFormat` splices the result back into the
# schema the type mapper already produced, wherever it left its
# "application/octet-stream" placeholder (mapFileType's sentinel for "this is
# a File/stdout/stderr, format unresolved").

# Expand a single CWL format value ("iana:image/png") through $namespaces,
# the same prefix expansion used for annotation keys (matchedPrefix). A
# format with no declared prefix, or already a full IRI, is returned as-is.
def expandFormat($ns):
  . as $f |
  ($f | matchedPrefix($ns)) as $p |
  if $p then ($ns[$p] + $f[($p | length) + 1:]) else $f end;

# Resolve one already-expanded format IRI to an OGC API - Processes media
# type, or null when not recognised.
#
# IANA media-type IRIs resolve mechanically: under
# https://www.iana.org/assignments/media-types/, the path *is* the media
# type (RFC 6838 registry convention), e.g. .../image/jp2 -> "image/jp2".
#
# OGC media-type IRIs do NOT encode their media type in the IRI. Each
# concept under http://www.opengis.net/def/media-type/ogc/1.0/<slug>
# publishes it as a `skos:notation` on the OGC Definitions Server (verified
# 2026-09-23: .../geotiff -> skos:notation "image/tiff; application=geotiff"
# typed <https://www.iana.org/assignments/media-types>). jq has no HTTP
# client, so this table is a manually maintained mirror of that register;
# extend it as OGC defines further media types. An unrecognised slug (or an
# unrecognised namespace altogether) resolves to null, which
# mapFileFormat/applyFormat drop silently rather than fail the transform.
def resolveMediaType:
  ("https://www.iana.org/assignments/media-types/") as $iana |
  ("http://www.opengis.net/def/media-type/ogc/1.0/") as $ogc |
  if startswith($iana) then
    .[($iana | length):]
  elif startswith($ogc) then
    (.[($ogc | length):]) as $slug |
    ({ "geotiff": "image/tiff; application=geotiff" }[$slug])
  else
    null
  end;

# CWL `format` (a string, a list, or null/absent) -> the OGC API - Processes
# Part 1 binary-input schema fragment for it: a single {contentMediaType},
# or `oneOf` of one binary schema per accepted media type when more than one
# resolves. The `oneOf` shape is carried over from how this project's own
# consumers were already correcting this by hand (Q-M02 in
# GeoLabs/bblocks-process-profiles remains open on whether `oneOf` or
# `anyOf` is the better fit, since the branches differ only by annotation).
# Returns null when `format` is absent or none of its values resolve, so
# callers leave the type mapper's own placeholder in place.
def mapFileFormat($ns):
  . as $format |
  if $format == null then null else
    ($format
     | (if type == "array" then . else [.] end)
     | map(expandFormat($ns) | resolveMediaType)
     | map(select(. != null))
     | dedup) as $media |
    if ($media | length) == 0 then null
    elif ($media | length) == 1 then
      { type: "string", contentMediaType: $media[0], contentEncoding: "binary" }
    else
      # No sibling `type` here: each oneOf branch already declares its own
      # `type: "string"`, matching the shape this project's own consumers
      # were already producing by hand.
      { oneOf: ($media | map({ type: "string", contentMediaType: ., contentEncoding: "binary" })) }
    end
  end;

# Splice a resolved format schema into whatever the type mapper produced, at
# any depth: inside `items` for a File[] parameter, inside each `oneOf`
# branch for a union type. Every node the type mapper left as
# "application/octet-stream" is a File/stdout/stderr leaf and a valid splice
# point; a Directory leaf ("application/x-directory") is never touched,
# since CWL `format` does not apply to directories.
def applyFormat($formatSchema):
  if $formatSchema == null then . else
    walk(if (type == "object" and .contentMediaType == "application/octet-stream")
         then $formatSchema else . end)
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
def inputDescription($id; $ns):
  . as $param |
  ($param.type) as $t |
  ($param.format | mapFileFormat($ns)) as $formatSchema |
  {
    title: ($param.label // $id),
    description: ($param.doc // ""),
    schema: ((($t | mapType) | applyFormat($formatSchema))
             + (if ($param | has("default")) then { default: $param.default } else {} end)),
    minOccurs: (if ($t | isOptionalType) or ($param | has("default")) then 0 else 1 end),
    maxOccurs: 1
  };

# Build one OGC output description from a CWL output parameter object
def outputDescription($id; $ns):
  . as $param |
  ($param.format | mapFileFormat($ns)) as $formatSchema |
  {
    title: ($param.label // $id),
    description: ($param.doc // ""),
    schema: (($param.type | mapOutputType) | applyFormat($formatSchema))
  };

# Process inputs
def processInputs($ns):
  if . then
    if (. | type) == "array" then
      # Workflow style: inputs is an array with id fields
      map(.id as $id | { key: $id, value: inputDescription($id; $ns) }) | from_entries
    else
      # CommandLineTool style: inputs is an object
      to_entries | map(.key as $id | { key: $id, value: (.value | inputDescription($id; $ns)) }) | from_entries
    end
  else
    {}
  end;

# Process outputs
def processOutputs($ns):
  if . then
    if (. | type) == "array" then
      # Workflow style: outputs is an array with id fields
      map(.id as $id | { key: $id, value: outputDescription($id; $ns) }) | from_entries
    else
      # CommandLineTool style: outputs is an object
      to_entries | map(.key as $id | { key: $id, value: (.value | outputDescription($id; $ns)) }) | from_entries
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
  inputs: ($root.inputs | processInputs($ns)),
  outputs: ($root.outputs | processOutputs($ns)),

  # A deployed CWL process can only be executed asynchronously
  jobControlOptions: ["async-execute"],
  outputTransmission: ["value", "reference"]
}
