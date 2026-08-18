
# CWL to OGC API Processes Profile (Model)

`eoap.cct.cwl-to-ogcprocess` *v1.0*

Profile for converting a CWL Workflow definition to an OGC API - Processes processDescription

[*Status*](http://www.opengis.net/def/status): Under development

## Description

This building block provides a comprehensive transformation profile that converts Common Workflow Language (CWL) definitions into OGC API - Processes processDescription schemas. Only the Workflow is described, along with all EOAP custom types.

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

1. **Select the Workflow**: Handle both direct CWL documents and those with a `$graph`, picking the Workflow that represents the process
2. **Process metadata**: Extract id, title, description from CWL document
3. **Preserve annotations**: Convert every prefixed annotation into an OGC `metadata` entry
4. **Map inputs**: Convert CWL inputs to OGC process inputs with appropriate schemas
5. **Map outputs**: Convert CWL outputs to OGC process outputs with appropriate schemas
6. **Add execution options**: Include jobControlOptions and outputTransmission modes

## Execution and deployment

A CWL process reaches the server through OGC API - Processes Part 2
(Deploy, Replace, Undeploy), which fixes two members regardless of the CWL content:

- `mutable: true` — the process was deployed, so it can be replaced and undeployed
- `jobControlOptions: ["async-execute", "dismiss"]` — a deployed CWL process cannot
  be run synchronously, so `sync-execute` is never advertised; a running job can be
  dismissed

## Only the Workflow is described

The deployed process is the CWL `Workflow`. A `CommandLineTool` is the implementation
of a step, not a process, and is never described — neither its inputs and outputs nor
its annotations reach the process description.

When a packed document holds several `Workflow` elements, the process is the one no
step runs: the sub-workflows referenced through a step's `run` are implementation
detail. An element whose id is `main` wins outright, following the CWL packing
convention. A document without any `Workflow` is an error rather than a process
description built from the wrong element.

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


## Examples

### BBox Workflow
#### yaml
```yaml
# Copyright 2025 Terradue
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cwlVersion: v1.2

$graph:
- class: Workflow
  id: bbox-workflow
  label: "OGC BBox Processing Workflow"
  doc: "Workflow that processes OGC BBox input and generates output"
  
  requirements:
    - class: InlineJavascriptRequirement
    - class: SchemaDefRequirement
      types:
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml
  
  inputs:
    - id: aoi
      type: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox
      label: "Area of interest"
      doc: "Area of interest defined as a bounding box"
  
  outputs:
    - id: echo_output
      type: File
      outputSource:
        - echo_step/echo_output
      label: "Echo output"
      doc: "Echoed BBox information"
  
  steps:
    echo_step:
      run: "#clt"
      in:
        aoi: aoi
      out:
        - echo_output

- class: CommandLineTool
  id: clt
  label: "Echo OGC BBox"
  baseCommand: echo
  
  requirements:
    - class: InlineJavascriptRequirement
    - class: SchemaDefRequirement
      types:
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml
  
  inputs:
    aoi:
      type: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox
      label: "Area of interest"
      doc: "Area of interest defined as a bounding box"
      inputBinding:
        valueFrom: |
          ${
            // Validate the length of bbox to be either 4 or 6
            var bboxLength = inputs.aoi.bbox.length;
            if (bboxLength !== 4 && bboxLength !== 6) {
              throw "Invalid bbox length: bbox must have either 4 or 6 elements.";
            }
            // Convert bbox array to a space-separated string for echo
            return inputs.aoi.bbox.join(' ') + " CRS: " + inputs.aoi.crs;
          }
  
  outputs:
    echo_output:
      type: stdout
  
  stdout: echo_output.txt

```

#### json
```json
{
  "cwlVersion": "v1.2",
  "$graph": [
    {
      "class": "Workflow",
      "id": "bbox-workflow",
      "label": "OGC BBox Processing Workflow",
      "doc": "Workflow that processes OGC BBox input and generates output",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml"
            }
          ]
        }
      ],
      "inputs": [
        {
          "id": "aoi",
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox",
          "label": "Area of interest",
          "doc": "Area of interest defined as a bounding box"
        }
      ],
      "outputs": [
        {
          "id": "echo_output",
          "type": "File",
          "outputSource": [
            "echo_step/echo_output"
          ],
          "label": "Echo output",
          "doc": "Echoed BBox information"
        }
      ],
      "steps": {
        "echo_step": {
          "run": "#clt",
          "in": {
            "aoi": "aoi"
          },
          "out": [
            "echo_output"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "clt",
      "label": "Echo OGC BBox",
      "baseCommand": "echo",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml"
            }
          ]
        }
      ],
      "inputs": {
        "aoi": {
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox",
          "label": "Area of interest",
          "doc": "Area of interest defined as a bounding box",
          "inputBinding": {
            "valueFrom": "${\n  // Validate the length of bbox to be either 4 or 6\n  var bboxLength = inputs.aoi.bbox.length;\n  if (bboxLength !== 4 && bboxLength !== 6) {\n    throw \"Invalid bbox length: bbox must have either 4 or 6 elements.\";\n  }\n  // Convert bbox array to a space-separated string for echo\n  return inputs.aoi.bbox.join(' ') + \" CRS: \" + inputs.aoi.crs;\n}\n"
          }
        }
      },
      "outputs": {
        "echo_output": {
          "type": "stdout"
        }
      },
      "stdout": "echo_output.txt"
    }
  ]
}

```

#### jsonld
```jsonld
{
  "@context": "https://geolabs.github.io/bblocks-eoap-cct/build/annotated/cct/cwl-to-ogcprocess/context.jsonld",
  "cwlVersion": "v1.2",
  "$graph": [
    {
      "class": "Workflow",
      "id": "bbox-workflow",
      "label": "OGC BBox Processing Workflow",
      "doc": "Workflow that processes OGC BBox input and generates output",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml"
            }
          ]
        }
      ],
      "inputs": [
        {
          "id": "aoi",
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox",
          "label": "Area of interest",
          "doc": "Area of interest defined as a bounding box"
        }
      ],
      "outputs": [
        {
          "id": "echo_output",
          "type": "File",
          "outputSource": [
            "echo_step/echo_output"
          ],
          "label": "Echo output",
          "doc": "Echoed BBox information"
        }
      ],
      "steps": {
        "echo_step": {
          "run": "#clt",
          "in": {
            "aoi": "aoi"
          },
          "out": [
            "echo_output"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "clt",
      "label": "Echo OGC BBox",
      "baseCommand": "echo",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml"
            }
          ]
        }
      ],
      "inputs": {
        "aoi": {
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox",
          "label": "Area of interest",
          "doc": "Area of interest defined as a bounding box",
          "inputBinding": {
            "valueFrom": "${\n  // Validate the length of bbox to be either 4 or 6\n  var bboxLength = inputs.aoi.bbox.length;\n  if (bboxLength !== 4 && bboxLength !== 6) {\n    throw \"Invalid bbox length: bbox must have either 4 or 6 elements.\";\n  }\n  // Convert bbox array to a space-separated string for echo\n  return inputs.aoi.bbox.join(' ') + \" CRS: \" + inputs.aoi.crs;\n}\n"
          }
        }
      },
      "outputs": {
        "echo_output": {
          "type": "stdout"
        }
      },
      "stdout": "echo_output.txt"
    }
  ]
}
```

#### ttl
```ttl
@prefix cwl: <https://w3id.org/cwl/cwl#> .
@prefix dct: <http://purl.org/dc/terms/> .
@prefix ns1: <rdf:> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

[] cwl:cwlVersion <file:///github/workspace/v1.2> ;
    cwl:graph [ rdfs:label "Echo OGC BBox"^^xsd:string ;
            dct:identifier <file:///github/workspace/clt> ;
            cwl:baseCommand "\"echo\""^^rdf:JSON ;
            cwl:input ( [ cwl:aoi [ rdfs:label "Area of interest"^^xsd:string ;
                                rdfs:comment "Area of interest defined as a bounding box"^^xsd:string ;
                                cwl:inputBinding [ cwl:valueFrom """${
  // Validate the length of bbox to be either 4 or 6
  var bboxLength = inputs.aoi.bbox.length;
  if (bboxLength !== 4 && bboxLength !== 6) {
    throw "Invalid bbox length: bbox must have either 4 or 6 elements.";
  }
  // Convert bbox array to a space-separated string for echo
  return inputs.aoi.bbox.join(' ') + " CRS: " + inputs.aoi.crs;
}
"""^^xsd:string ] ;
                                cwl:type <https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox> ] ] ) ;
            cwl:output ( [ cwl:echo_output [ cwl:type <file:///github/workspace/stdout> ] ] ) ;
            cwl:requirements [ cwl:types [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml> ] ;
                    ns1:type <file:///github/workspace/SchemaDefRequirement> ],
                [ ns1:type <file:///github/workspace/InlineJavascriptRequirement> ] ;
            cwl:stdout "echo_output.txt"^^xsd:string ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ rdfs:label "OGC BBox Processing Workflow"^^xsd:string ;
            dct:identifier <file:///github/workspace/bbox-workflow> ;
            rdfs:comment "Workflow that processes OGC BBox input and generates output"^^xsd:string ;
            cwl:input ( [ rdfs:label "Area of interest"^^xsd:string ;
                        dct:identifier <file:///github/workspace/aoi> ;
                        rdfs:comment "Area of interest defined as a bounding box"^^xsd:string ;
                        cwl:type <https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox> ] ) ;
            cwl:output ( [ rdfs:label "Echo output"^^xsd:string ;
                        dct:identifier <file:///github/workspace/echo_output> ;
                        rdfs:comment "Echoed BBox information"^^xsd:string ;
                        cwl:outputSource <file:///github/workspace/echo_step/echo_output> ;
                        cwl:type <file:///github/workspace/File> ] ) ;
            cwl:requirements [ ns1:type <file:///github/workspace/InlineJavascriptRequirement> ],
                [ cwl:types [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml> ] ;
                    ns1:type <file:///github/workspace/SchemaDefRequirement> ] ;
            cwl:steps [ cwl:echo_step [ cwl:in [ cwl:aoi "aoi" ] ;
                            cwl:out ( "echo_output" ) ;
                            cwl:run <file:///github/workspace/#clt> ] ] ;
            ns1:type <file:///github/workspace/Workflow> ] .


```


### GeoJSON Feature Workflow
#### yaml
```yaml
# Copyright 2025 Terradue
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cwlVersion: v1.2

$graph:
- class: Workflow
  id: feature-workflow
  label: "GeoJSON Feature Processing Workflow"
  doc: "Workflow that processes GeoJSON Feature input and generates output"
  
  requirements:
    - class: InlineJavascriptRequirement
    - class: SchemaDefRequirement
      types:
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
  
  inputs:
    - id: aoi
      type: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Feature
      label: "Area of interest"
      doc: "Area of interest defined in GeoJSON format"
  
  outputs:
    - id: echo_output
      type: File
      outputSource:
        - echo_step/echo_output
      label: "Echo output"
      doc: "Echoed GeoJSON Feature information"
  
  steps:
    echo_step:
      run: "#clt"
      in:
        aoi: aoi
      out:
        - echo_output

- class: CommandLineTool
  id: clt
  label: "Echo GeoJSON Feature"
  baseCommand: echo
  
  requirements:
    - class: InlineJavascriptRequirement
    - class: SchemaDefRequirement
      types:
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
  
  inputs:
    aoi:
      type: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Feature
      label: "Area of interest"
      doc: "Area of interest defined in GeoJSON format"
      inputBinding:
        valueFrom: |
          ${
            // Validate if type is 'Feature'
            if (inputs.aoi.type !== 'Feature') {
              throw "Invalid GeoJSON type: expected 'Feature', got '" + inputs.aoi.type + "'";
            }
            // get the Feature geometry type
            return "Feature with id '" + inputs.aoi.id + "' is of type: " + inputs.aoi.geometry.type;
          }
  
  outputs:
    echo_output:
      type: stdout
  
  stdout: echo_output.txt

```

#### json
```json
{
  "cwlVersion": "v1.2",
  "$graph": [
    {
      "class": "Workflow",
      "id": "feature-workflow",
      "label": "GeoJSON Feature Processing Workflow",
      "doc": "Workflow that processes GeoJSON Feature input and generates output",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml"
            }
          ]
        }
      ],
      "inputs": [
        {
          "id": "aoi",
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Feature",
          "label": "Area of interest",
          "doc": "Area of interest defined in GeoJSON format"
        }
      ],
      "outputs": [
        {
          "id": "echo_output",
          "type": "File",
          "outputSource": [
            "echo_step/echo_output"
          ],
          "label": "Echo output",
          "doc": "Echoed GeoJSON Feature information"
        }
      ],
      "steps": {
        "echo_step": {
          "run": "#clt",
          "in": {
            "aoi": "aoi"
          },
          "out": [
            "echo_output"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "clt",
      "label": "Echo GeoJSON Feature",
      "baseCommand": "echo",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml"
            }
          ]
        }
      ],
      "inputs": {
        "aoi": {
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Feature",
          "label": "Area of interest",
          "doc": "Area of interest defined in GeoJSON format",
          "inputBinding": {
            "valueFrom": "${\n  // Validate if type is 'Feature'\n  if (inputs.aoi.type !== 'Feature') {\n    throw \"Invalid GeoJSON type: expected 'Feature', got '\" + inputs.aoi.type + \"'\";\n  }\n  // get the Feature geometry type\n  return \"Feature with id '\" + inputs.aoi.id + \"' is of type: \" + inputs.aoi.geometry.type;\n}\n"
          }
        }
      },
      "outputs": {
        "echo_output": {
          "type": "stdout"
        }
      },
      "stdout": "echo_output.txt"
    }
  ]
}

```

#### jsonld
```jsonld
{
  "@context": "https://geolabs.github.io/bblocks-eoap-cct/build/annotated/cct/cwl-to-ogcprocess/context.jsonld",
  "cwlVersion": "v1.2",
  "$graph": [
    {
      "class": "Workflow",
      "id": "feature-workflow",
      "label": "GeoJSON Feature Processing Workflow",
      "doc": "Workflow that processes GeoJSON Feature input and generates output",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml"
            }
          ]
        }
      ],
      "inputs": [
        {
          "id": "aoi",
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Feature",
          "label": "Area of interest",
          "doc": "Area of interest defined in GeoJSON format"
        }
      ],
      "outputs": [
        {
          "id": "echo_output",
          "type": "File",
          "outputSource": [
            "echo_step/echo_output"
          ],
          "label": "Echo output",
          "doc": "Echoed GeoJSON Feature information"
        }
      ],
      "steps": {
        "echo_step": {
          "run": "#clt",
          "in": {
            "aoi": "aoi"
          },
          "out": [
            "echo_output"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "clt",
      "label": "Echo GeoJSON Feature",
      "baseCommand": "echo",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml"
            }
          ]
        }
      ],
      "inputs": {
        "aoi": {
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Feature",
          "label": "Area of interest",
          "doc": "Area of interest defined in GeoJSON format",
          "inputBinding": {
            "valueFrom": "${\n  // Validate if type is 'Feature'\n  if (inputs.aoi.type !== 'Feature') {\n    throw \"Invalid GeoJSON type: expected 'Feature', got '\" + inputs.aoi.type + \"'\";\n  }\n  // get the Feature geometry type\n  return \"Feature with id '\" + inputs.aoi.id + \"' is of type: \" + inputs.aoi.geometry.type;\n}\n"
          }
        }
      },
      "outputs": {
        "echo_output": {
          "type": "stdout"
        }
      },
      "stdout": "echo_output.txt"
    }
  ]
}
```

#### ttl
```ttl
@prefix cwl: <https://w3id.org/cwl/cwl#> .
@prefix dct: <http://purl.org/dc/terms/> .
@prefix ns1: <rdf:> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

[] cwl:cwlVersion <file:///github/workspace/v1.2> ;
    cwl:graph [ rdfs:label "Echo GeoJSON Feature"^^xsd:string ;
            dct:identifier <file:///github/workspace/clt> ;
            cwl:baseCommand "\"echo\""^^rdf:JSON ;
            cwl:input ( [ cwl:aoi [ rdfs:label "Area of interest"^^xsd:string ;
                                rdfs:comment "Area of interest defined in GeoJSON format"^^xsd:string ;
                                cwl:inputBinding [ cwl:valueFrom """${
  // Validate if type is 'Feature'
  if (inputs.aoi.type !== 'Feature') {
    throw "Invalid GeoJSON type: expected 'Feature', got '" + inputs.aoi.type + "'";
  }
  // get the Feature geometry type
  return "Feature with id '" + inputs.aoi.id + "' is of type: " + inputs.aoi.geometry.type;
}
"""^^xsd:string ] ;
                                cwl:type <https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Feature> ] ] ) ;
            cwl:output ( [ cwl:echo_output [ cwl:type <file:///github/workspace/stdout> ] ] ) ;
            cwl:requirements [ cwl:types [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml> ] ;
                    ns1:type <file:///github/workspace/SchemaDefRequirement> ],
                [ ns1:type <file:///github/workspace/InlineJavascriptRequirement> ] ;
            cwl:stdout "echo_output.txt"^^xsd:string ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ rdfs:label "GeoJSON Feature Processing Workflow"^^xsd:string ;
            dct:identifier <file:///github/workspace/feature-workflow> ;
            rdfs:comment "Workflow that processes GeoJSON Feature input and generates output"^^xsd:string ;
            cwl:input ( [ rdfs:label "Area of interest"^^xsd:string ;
                        dct:identifier <file:///github/workspace/aoi> ;
                        rdfs:comment "Area of interest defined in GeoJSON format"^^xsd:string ;
                        cwl:type <https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Feature> ] ) ;
            cwl:output ( [ rdfs:label "Echo output"^^xsd:string ;
                        dct:identifier <file:///github/workspace/echo_output> ;
                        rdfs:comment "Echoed GeoJSON Feature information"^^xsd:string ;
                        cwl:outputSource <file:///github/workspace/echo_step/echo_output> ;
                        cwl:type <file:///github/workspace/File> ] ) ;
            cwl:requirements [ cwl:types [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml> ] ;
                    ns1:type <file:///github/workspace/SchemaDefRequirement> ],
                [ ns1:type <file:///github/workspace/InlineJavascriptRequirement> ] ;
            cwl:steps [ cwl:echo_step [ cwl:in [ cwl:aoi "aoi" ] ;
                            cwl:out ( "echo_output" ) ;
                            cwl:run <file:///github/workspace/#clt> ] ] ;
            ns1:type <file:///github/workspace/Workflow> ] .


```


### STAC Item Workflow
#### yaml
```yaml
# Copyright 2025 Terradue
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cwlVersion: v1.2

$graph:
- class: Workflow
  id: item-workflow
  label: "STAC Item Processing Workflow"
  doc: "Workflow that processes STAC Item input and generates output"
  
  requirements:
    - class: InlineJavascriptRequirement
    - class: SchemaDefRequirement
      types:
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml
  
  inputs:
    - id: stac_item
      type: https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml#Item
      label: "STAC Item"
      doc: "STAC Item representing a geospatial asset"
  
  outputs:
    - id: result
      type: File
      outputSource:
        - process_step/result
      label: "Process result"
      doc: "Processed STAC Item information"
  
  steps:
    process_step:
      run: "#clt"
      in:
        stac_item: stac_item
      out:
        - result

- class: CommandLineTool
  id: clt
  label: "Process STAC Item"
  baseCommand: echo
  
  requirements:
    - class: InlineJavascriptRequirement
    - class: SchemaDefRequirement
      types:
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml
  
  inputs:
    stac_item:
      type: https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml#Item
      label: "STAC Item"
      doc: "STAC Item representing a geospatial asset"
      inputBinding:
        valueFrom: |
          ${
            return "STAC Item ID: " + inputs.stac_item.id;
          }
  
  outputs:
    result:
      type: stdout
  
  stdout: result.txt

```

#### json
```json
{
  "cwlVersion": "v1.2",
  "$graph": [
    {
      "class": "Workflow",
      "id": "item-workflow",
      "label": "STAC Item Processing Workflow",
      "doc": "Workflow that processes STAC Item input and generates output",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml"
            }
          ]
        }
      ],
      "inputs": [
        {
          "id": "stac_item",
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml#Item",
          "label": "STAC Item",
          "doc": "STAC Item representing a geospatial asset"
        }
      ],
      "outputs": [
        {
          "id": "result",
          "type": "File",
          "outputSource": [
            "process_step/result"
          ],
          "label": "Process result",
          "doc": "Processed STAC Item information"
        }
      ],
      "steps": {
        "process_step": {
          "run": "#clt",
          "in": {
            "stac_item": "stac_item"
          },
          "out": [
            "result"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "clt",
      "label": "Process STAC Item",
      "baseCommand": "echo",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml"
            }
          ]
        }
      ],
      "inputs": {
        "stac_item": {
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml#Item",
          "label": "STAC Item",
          "doc": "STAC Item representing a geospatial asset",
          "inputBinding": {
            "valueFrom": "${\n  return \"STAC Item ID: \" + inputs.stac_item.id;\n}\n"
          }
        }
      },
      "outputs": {
        "result": {
          "type": "stdout"
        }
      },
      "stdout": "result.txt"
    }
  ]
}

```

#### jsonld
```jsonld
{
  "@context": "https://geolabs.github.io/bblocks-eoap-cct/build/annotated/cct/cwl-to-ogcprocess/context.jsonld",
  "cwlVersion": "v1.2",
  "$graph": [
    {
      "class": "Workflow",
      "id": "item-workflow",
      "label": "STAC Item Processing Workflow",
      "doc": "Workflow that processes STAC Item input and generates output",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml"
            }
          ]
        }
      ],
      "inputs": [
        {
          "id": "stac_item",
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml#Item",
          "label": "STAC Item",
          "doc": "STAC Item representing a geospatial asset"
        }
      ],
      "outputs": [
        {
          "id": "result",
          "type": "File",
          "outputSource": [
            "process_step/result"
          ],
          "label": "Process result",
          "doc": "Processed STAC Item information"
        }
      ],
      "steps": {
        "process_step": {
          "run": "#clt",
          "in": {
            "stac_item": "stac_item"
          },
          "out": [
            "result"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "clt",
      "label": "Process STAC Item",
      "baseCommand": "echo",
      "requirements": [
        {
          "class": "InlineJavascriptRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml"
            }
          ]
        }
      ],
      "inputs": {
        "stac_item": {
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml#Item",
          "label": "STAC Item",
          "doc": "STAC Item representing a geospatial asset",
          "inputBinding": {
            "valueFrom": "${\n  return \"STAC Item ID: \" + inputs.stac_item.id;\n}\n"
          }
        }
      },
      "outputs": {
        "result": {
          "type": "stdout"
        }
      },
      "stdout": "result.txt"
    }
  ]
}
```

#### ttl
```ttl
@prefix cwl: <https://w3id.org/cwl/cwl#> .
@prefix dct: <http://purl.org/dc/terms/> .
@prefix ns1: <rdf:> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

[] cwl:cwlVersion <file:///github/workspace/v1.2> ;
    cwl:graph [ rdfs:label "STAC Item Processing Workflow"^^xsd:string ;
            dct:identifier <file:///github/workspace/item-workflow> ;
            rdfs:comment "Workflow that processes STAC Item input and generates output"^^xsd:string ;
            cwl:input ( [ rdfs:label "STAC Item"^^xsd:string ;
                        dct:identifier <file:///github/workspace/stac_item> ;
                        rdfs:comment "STAC Item representing a geospatial asset"^^xsd:string ;
                        cwl:type <https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml#Item> ] ) ;
            cwl:output ( [ rdfs:label "Process result"^^xsd:string ;
                        dct:identifier <file:///github/workspace/result> ;
                        rdfs:comment "Processed STAC Item information"^^xsd:string ;
                        cwl:outputSource <file:///github/workspace/process_step/result> ;
                        cwl:type <file:///github/workspace/File> ] ) ;
            cwl:requirements [ cwl:types [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml> ] ;
                    ns1:type <file:///github/workspace/SchemaDefRequirement> ],
                [ ns1:type <file:///github/workspace/InlineJavascriptRequirement> ] ;
            cwl:steps [ cwl:process_step [ cwl:in [ cwl:stac_item "stac_item" ] ;
                            cwl:out ( "result" ) ;
                            cwl:run <file:///github/workspace/#clt> ] ] ;
            ns1:type <file:///github/workspace/Workflow> ],
        [ rdfs:label "Process STAC Item"^^xsd:string ;
            dct:identifier <file:///github/workspace/clt> ;
            cwl:baseCommand "\"echo\""^^rdf:JSON ;
            cwl:input ( [ cwl:stac_item [ rdfs:label "STAC Item"^^xsd:string ;
                                rdfs:comment "STAC Item representing a geospatial asset"^^xsd:string ;
                                cwl:inputBinding [ cwl:valueFrom """${
  return "STAC Item ID: " + inputs.stac_item.id;
}
"""^^xsd:string ] ;
                                cwl:type <https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml#Item> ] ] ) ;
            cwl:output ( [ cwl:result [ cwl:type <file:///github/workspace/stdout> ] ] ) ;
            cwl:requirements [ ns1:type <file:///github/workspace/InlineJavascriptRequirement> ],
                [ cwl:types [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml> ] ;
                    ns1:type <file:///github/workspace/SchemaDefRequirement> ] ;
            cwl:stdout "result.txt"^^xsd:string ;
            ns1:type <file:///github/workspace/CommandLineTool> ] .


```


### Water Bodies Detection Workflow
#### yaml
```yaml
cwlVersion: v1.0
$namespaces:
  s: https://schema.org/
s:softwareVersion: 1.4.1
schemas:
  - http://schema.org/version/9.0/schemaorg-current-http.rdf
$graph:
  - class: Workflow
    id: water-bodies
    label: Water bodies detection based on NDWI and otsu threshold
    doc: Water bodies detection based on NDWI and otsu threshold applied to Sentinel-2 COG STAC items
    requirements:
      - class: ScatterFeatureRequirement
      - class: SubworkflowFeatureRequirement
      - class: SchemaDefRequirement
        types:
        - $import: https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml
    inputs:
      aoi:
        label: area of interest
        doc: area of interest as a bounding box
        type: string
      epsg:
        label: EPSG code
        doc: EPSG code
        type: string
        default: "EPSG:4326"
      stac_items:
        label: Sentinel-2 STAC items
        doc: list of Sentinel-2 COG STAC items
        type: string[]
      bands:
        label: bands used for the NDWI
        doc: bands used for the NDWI
        type: string[]
        default: ["green", "nir"]
    outputs:
      - id: stac_catalog
        outputSource:
          - node_stac/stac_catalog
        type: Directory
    steps:
      node_water_bodies:
        run: "#detect_water_body"
        in:
          item: stac_items
          aoi: aoi
          epsg: epsg
          bands: bands
        out:
          - detected_water_body
        scatter: item
        scatterMethod: dotproduct
      node_stac:
        run: "#stac"
        in:
          item: stac_items
          rasters:
            source: node_water_bodies/detected_water_body
        out:
          - stac_catalog
  - class: Workflow
    id: detect_water_body
    label: Water body detection based on NDWI and otsu threshold
    doc: Water body detection based on NDWI and otsu threshold
    requirements:
      - class: ScatterFeatureRequirement
    inputs:
      aoi:
        doc: area of interest as a bounding box
        type: string
      epsg:
        doc: EPSG code
        type: string
        default: "EPSG:4326"
      bands:
        doc: bands used for the NDWI
        type: string[]
      item:
        doc: STAC item
        type: string
    outputs:
      - id: detected_water_body
        outputSource:
          - node_otsu/binary_mask_item
        type: File
    steps:
      node_crop:
        run: "#crop"
        in:
          item: item
          aoi: aoi
          epsg: epsg
          band: bands
        out:
          - cropped
        scatter: band
        scatterMethod: dotproduct
      node_normalized_difference:
        run: "#norm_diff"
        in:
          rasters:
            source: node_crop/cropped
        out:
          - ndwi
      node_otsu:
        run: "#otsu"
        in:
          raster:
            source: node_normalized_difference/ndwi
        out:
          - binary_mask_item
  - class: CommandLineTool
    id: crop
    requirements:
      InlineJavascriptRequirement: {}
      EnvVarRequirement:
        envDef:
          PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
          PYTHONPATH: /app
      ResourceRequirement:
        coresMax: 1
        ramMax: 512
    hints:
      DockerRequirement:
        dockerPull: cr.terradue.com/earthquake-monitoring/crop:latest
    baseCommand: ["python", "-m", "app"]
    arguments: []
    inputs:
      item:
        type: string
        inputBinding:
          prefix: --input-item
      aoi:
        type: string
        inputBinding:
          prefix: --aoi
      epsg:
        type: string
        inputBinding:
          prefix: --epsg
      band:
        type: string
        inputBinding:
          prefix: --band
    outputs:
      cropped:
        outputBinding:
          glob: '*.tif'
        type: File
  - class: CommandLineTool
    id: norm_diff
    requirements:
      InlineJavascriptRequirement: {}
      EnvVarRequirement:
        envDef:
          PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
          PYTHONPATH: /app
      ResourceRequirement:
        coresMax: 1
        ramMax: 512
    hints:
      DockerRequirement:
        dockerPull: cr.terradue.com/earthquake-monitoring/norm_diff:latest
    baseCommand: ["python", "-m", "app"]
    arguments: []
    inputs:
      rasters:
        type: File[]
        inputBinding:
          position: 1
    outputs:
      ndwi:
        outputBinding:
          glob: '*.tif'
        type: File
  - class: CommandLineTool
    id: otsu
    requirements:
      InlineJavascriptRequirement: {}
      EnvVarRequirement:
        envDef:
          PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
          PYTHONPATH: /app
      ResourceRequirement:
        coresMax: 1
        ramMax: 512
    hints:
      DockerRequirement:
        dockerPull: cr.terradue.com/earthquake-monitoring/otsu:latest
    baseCommand: ["python", "-m", "app"]
    arguments: []
    inputs:
      raster:
        type: File
        inputBinding:
          position: 1
    outputs:
      binary_mask_item:
        outputBinding:
          glob: '*.tif'
        type: File
  - class: CommandLineTool
    id: stac
    requirements:
      InlineJavascriptRequirement: {}
      EnvVarRequirement:
        envDef:
          PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
          PYTHONPATH: /app
      ResourceRequirement:
        coresMax: 1
        ramMax: 512
    hints:
      DockerRequirement:
        dockerPull: cr.terradue.com/earthquake-monitoring/stac:latest
    baseCommand: ["python", "-m", "app"]
    arguments: []
    inputs:
      item:
        type:
          type: array
          items: string
          inputBinding:
            prefix: --input-item
      rasters:
        type:
          type: array
          items: File
          inputBinding:
            prefix: --water-body
    outputs:
      stac_catalog:
        outputBinding:
          glob: .
        type: Directory

```

#### json
```json
{
  "cwlVersion": "v1.0",
  "$namespaces": {
    "s": "https://schema.org/"
  },
  "s:softwareVersion": "1.4.1",
  "schemas": [
    "http://schema.org/version/9.0/schemaorg-current-http.rdf"
  ],
  "$graph": [
    {
      "class": "Workflow",
      "id": "water-bodies",
      "label": "Water bodies detection based on NDWI and otsu threshold",
      "doc": "Water bodies detection based on NDWI and otsu threshold applied to Sentinel-2 COG STAC items",
      "requirements": [
        {
          "class": "ScatterFeatureRequirement"
        },
        {
          "class": "SubworkflowFeatureRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml"
            }
          ]
        }
      ],
      "inputs": {
        "aoi": {
          "label": "area of interest",
          "doc": "area of interest as a bounding box",
          "type": "string"
        },
        "epsg": {
          "label": "EPSG code",
          "doc": "EPSG code",
          "type": "string",
          "default": "EPSG:4326"
        },
        "stac_items": {
          "label": "Sentinel-2 STAC items",
          "doc": "list of Sentinel-2 COG STAC items",
          "type": "string[]"
        },
        "bands": {
          "label": "bands used for the NDWI",
          "doc": "bands used for the NDWI",
          "type": "string[]",
          "default": [
            "green",
            "nir"
          ]
        }
      },
      "outputs": [
        {
          "id": "stac_catalog",
          "outputSource": [
            "node_stac/stac_catalog"
          ],
          "type": "Directory"
        }
      ],
      "steps": {
        "node_water_bodies": {
          "run": "#detect_water_body",
          "in": {
            "item": "stac_items",
            "aoi": "aoi",
            "epsg": "epsg",
            "bands": "bands"
          },
          "out": [
            "detected_water_body"
          ],
          "scatter": "item",
          "scatterMethod": "dotproduct"
        },
        "node_stac": {
          "run": "#stac",
          "in": {
            "item": "stac_items",
            "rasters": {
              "source": "node_water_bodies/detected_water_body"
            }
          },
          "out": [
            "stac_catalog"
          ]
        }
      }
    },
    {
      "class": "Workflow",
      "id": "detect_water_body",
      "label": "Water body detection based on NDWI and otsu threshold",
      "doc": "Water body detection based on NDWI and otsu threshold",
      "requirements": [
        {
          "class": "ScatterFeatureRequirement"
        }
      ],
      "inputs": {
        "aoi": {
          "doc": "area of interest as a bounding box",
          "type": "string"
        },
        "epsg": {
          "doc": "EPSG code",
          "type": "string",
          "default": "EPSG:4326"
        },
        "bands": {
          "doc": "bands used for the NDWI",
          "type": "string[]"
        },
        "item": {
          "doc": "STAC item",
          "type": "string"
        }
      },
      "outputs": [
        {
          "id": "detected_water_body",
          "outputSource": [
            "node_otsu/binary_mask_item"
          ],
          "type": "File"
        }
      ],
      "steps": {
        "node_crop": {
          "run": "#crop",
          "in": {
            "item": "item",
            "aoi": "aoi",
            "epsg": "epsg",
            "band": "bands"
          },
          "out": [
            "cropped"
          ],
          "scatter": "band",
          "scatterMethod": "dotproduct"
        },
        "node_normalized_difference": {
          "run": "#norm_diff",
          "in": {
            "rasters": {
              "source": "node_crop/cropped"
            }
          },
          "out": [
            "ndwi"
          ]
        },
        "node_otsu": {
          "run": "#otsu",
          "in": {
            "raster": {
              "source": "node_normalized_difference/ndwi"
            }
          },
          "out": [
            "binary_mask_item"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "crop",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "EnvVarRequirement": {
          "envDef": {
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "PYTHONPATH": "/app"
          }
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "cr.terradue.com/earthquake-monitoring/crop:latest"
        }
      },
      "baseCommand": [
        "python",
        "-m",
        "app"
      ],
      "arguments": [],
      "inputs": {
        "item": {
          "type": "string",
          "inputBinding": {
            "prefix": "--input-item"
          }
        },
        "aoi": {
          "type": "string",
          "inputBinding": {
            "prefix": "--aoi"
          }
        },
        "epsg": {
          "type": "string",
          "inputBinding": {
            "prefix": "--epsg"
          }
        },
        "band": {
          "type": "string",
          "inputBinding": {
            "prefix": "--band"
          }
        }
      },
      "outputs": {
        "cropped": {
          "outputBinding": {
            "glob": "*.tif"
          },
          "type": "File"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "norm_diff",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "EnvVarRequirement": {
          "envDef": {
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "PYTHONPATH": "/app"
          }
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "cr.terradue.com/earthquake-monitoring/norm_diff:latest"
        }
      },
      "baseCommand": [
        "python",
        "-m",
        "app"
      ],
      "arguments": [],
      "inputs": {
        "rasters": {
          "type": "File[]",
          "inputBinding": {
            "position": 1
          }
        }
      },
      "outputs": {
        "ndwi": {
          "outputBinding": {
            "glob": "*.tif"
          },
          "type": "File"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "otsu",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "EnvVarRequirement": {
          "envDef": {
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "PYTHONPATH": "/app"
          }
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "cr.terradue.com/earthquake-monitoring/otsu:latest"
        }
      },
      "baseCommand": [
        "python",
        "-m",
        "app"
      ],
      "arguments": [],
      "inputs": {
        "raster": {
          "type": "File",
          "inputBinding": {
            "position": 1
          }
        }
      },
      "outputs": {
        "binary_mask_item": {
          "outputBinding": {
            "glob": "*.tif"
          },
          "type": "File"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "stac",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "EnvVarRequirement": {
          "envDef": {
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "PYTHONPATH": "/app"
          }
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "cr.terradue.com/earthquake-monitoring/stac:latest"
        }
      },
      "baseCommand": [
        "python",
        "-m",
        "app"
      ],
      "arguments": [],
      "inputs": {
        "item": {
          "type": {
            "type": "array",
            "items": "string",
            "inputBinding": {
              "prefix": "--input-item"
            }
          }
        },
        "rasters": {
          "type": {
            "type": "array",
            "items": "File",
            "inputBinding": {
              "prefix": "--water-body"
            }
          }
        }
      },
      "outputs": {
        "stac_catalog": {
          "outputBinding": {
            "glob": "."
          },
          "type": "Directory"
        }
      }
    }
  ]
}

```

#### jsonld
```jsonld
{
  "@context": "https://geolabs.github.io/bblocks-eoap-cct/build/annotated/cct/cwl-to-ogcprocess/context.jsonld",
  "cwlVersion": "v1.0",
  "$namespaces": {
    "s": "https://schema.org/"
  },
  "s:softwareVersion": "1.4.1",
  "schemas": [
    "http://schema.org/version/9.0/schemaorg-current-http.rdf"
  ],
  "$graph": [
    {
      "class": "Workflow",
      "id": "water-bodies",
      "label": "Water bodies detection based on NDWI and otsu threshold",
      "doc": "Water bodies detection based on NDWI and otsu threshold applied to Sentinel-2 COG STAC items",
      "requirements": [
        {
          "class": "ScatterFeatureRequirement"
        },
        {
          "class": "SubworkflowFeatureRequirement"
        },
        {
          "class": "SchemaDefRequirement",
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml"
            }
          ]
        }
      ],
      "inputs": {
        "aoi": {
          "label": "area of interest",
          "doc": "area of interest as a bounding box",
          "type": "string"
        },
        "epsg": {
          "label": "EPSG code",
          "doc": "EPSG code",
          "type": "string",
          "default": "EPSG:4326"
        },
        "stac_items": {
          "label": "Sentinel-2 STAC items",
          "doc": "list of Sentinel-2 COG STAC items",
          "type": "string[]"
        },
        "bands": {
          "label": "bands used for the NDWI",
          "doc": "bands used for the NDWI",
          "type": "string[]",
          "default": [
            "green",
            "nir"
          ]
        }
      },
      "outputs": [
        {
          "id": "stac_catalog",
          "outputSource": [
            "node_stac/stac_catalog"
          ],
          "type": "Directory"
        }
      ],
      "steps": {
        "node_water_bodies": {
          "run": "#detect_water_body",
          "in": {
            "item": "stac_items",
            "aoi": "aoi",
            "epsg": "epsg",
            "bands": "bands"
          },
          "out": [
            "detected_water_body"
          ],
          "scatter": "item",
          "scatterMethod": "dotproduct"
        },
        "node_stac": {
          "run": "#stac",
          "in": {
            "item": "stac_items",
            "rasters": {
              "source": "node_water_bodies/detected_water_body"
            }
          },
          "out": [
            "stac_catalog"
          ]
        }
      }
    },
    {
      "class": "Workflow",
      "id": "detect_water_body",
      "label": "Water body detection based on NDWI and otsu threshold",
      "doc": "Water body detection based on NDWI and otsu threshold",
      "requirements": [
        {
          "class": "ScatterFeatureRequirement"
        }
      ],
      "inputs": {
        "aoi": {
          "doc": "area of interest as a bounding box",
          "type": "string"
        },
        "epsg": {
          "doc": "EPSG code",
          "type": "string",
          "default": "EPSG:4326"
        },
        "bands": {
          "doc": "bands used for the NDWI",
          "type": "string[]"
        },
        "item": {
          "doc": "STAC item",
          "type": "string"
        }
      },
      "outputs": [
        {
          "id": "detected_water_body",
          "outputSource": [
            "node_otsu/binary_mask_item"
          ],
          "type": "File"
        }
      ],
      "steps": {
        "node_crop": {
          "run": "#crop",
          "in": {
            "item": "item",
            "aoi": "aoi",
            "epsg": "epsg",
            "band": "bands"
          },
          "out": [
            "cropped"
          ],
          "scatter": "band",
          "scatterMethod": "dotproduct"
        },
        "node_normalized_difference": {
          "run": "#norm_diff",
          "in": {
            "rasters": {
              "source": "node_crop/cropped"
            }
          },
          "out": [
            "ndwi"
          ]
        },
        "node_otsu": {
          "run": "#otsu",
          "in": {
            "raster": {
              "source": "node_normalized_difference/ndwi"
            }
          },
          "out": [
            "binary_mask_item"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "crop",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "EnvVarRequirement": {
          "envDef": {
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "PYTHONPATH": "/app"
          }
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "cr.terradue.com/earthquake-monitoring/crop:latest"
        }
      },
      "baseCommand": [
        "python",
        "-m",
        "app"
      ],
      "arguments": [],
      "inputs": {
        "item": {
          "type": "string",
          "inputBinding": {
            "prefix": "--input-item"
          }
        },
        "aoi": {
          "type": "string",
          "inputBinding": {
            "prefix": "--aoi"
          }
        },
        "epsg": {
          "type": "string",
          "inputBinding": {
            "prefix": "--epsg"
          }
        },
        "band": {
          "type": "string",
          "inputBinding": {
            "prefix": "--band"
          }
        }
      },
      "outputs": {
        "cropped": {
          "outputBinding": {
            "glob": "*.tif"
          },
          "type": "File"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "norm_diff",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "EnvVarRequirement": {
          "envDef": {
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "PYTHONPATH": "/app"
          }
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "cr.terradue.com/earthquake-monitoring/norm_diff:latest"
        }
      },
      "baseCommand": [
        "python",
        "-m",
        "app"
      ],
      "arguments": [],
      "inputs": {
        "rasters": {
          "type": "File[]",
          "inputBinding": {
            "position": 1
          }
        }
      },
      "outputs": {
        "ndwi": {
          "outputBinding": {
            "glob": "*.tif"
          },
          "type": "File"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "otsu",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "EnvVarRequirement": {
          "envDef": {
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "PYTHONPATH": "/app"
          }
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "cr.terradue.com/earthquake-monitoring/otsu:latest"
        }
      },
      "baseCommand": [
        "python",
        "-m",
        "app"
      ],
      "arguments": [],
      "inputs": {
        "raster": {
          "type": "File",
          "inputBinding": {
            "position": 1
          }
        }
      },
      "outputs": {
        "binary_mask_item": {
          "outputBinding": {
            "glob": "*.tif"
          },
          "type": "File"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "stac",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "EnvVarRequirement": {
          "envDef": {
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "PYTHONPATH": "/app"
          }
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "cr.terradue.com/earthquake-monitoring/stac:latest"
        }
      },
      "baseCommand": [
        "python",
        "-m",
        "app"
      ],
      "arguments": [],
      "inputs": {
        "item": {
          "type": {
            "type": "array",
            "items": "string",
            "inputBinding": {
              "prefix": "--input-item"
            }
          }
        },
        "rasters": {
          "type": {
            "type": "array",
            "items": "File",
            "inputBinding": {
              "prefix": "--water-body"
            }
          }
        }
      },
      "outputs": {
        "stac_catalog": {
          "outputBinding": {
            "glob": "."
          },
          "type": "Directory"
        }
      }
    }
  ]
}
```

#### ttl
```ttl
@prefix cwl: <https://w3id.org/cwl/cwl#> .
@prefix dct: <http://purl.org/dc/terms/> .
@prefix ns1: <rdf:> .
@prefix ns2: <s:> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

[] cwl:cwlVersion <file:///github/workspace/v1.0> ;
    cwl:graph [ rdfs:label "Water bodies detection based on NDWI and otsu threshold"^^xsd:string ;
            dct:identifier <file:///github/workspace/water-bodies> ;
            rdfs:comment "Water bodies detection based on NDWI and otsu threshold applied to Sentinel-2 COG STAC items"^^xsd:string ;
            cwl:input ( [ cwl:aoi [ rdfs:label "area of interest"^^xsd:string ;
                                rdfs:comment "area of interest as a bounding box"^^xsd:string ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:bands [ rdfs:label "bands used for the NDWI"^^xsd:string ;
                                rdfs:comment "bands used for the NDWI"^^xsd:string ;
                                cwl:default "[\"green\",\"nir\"]"^^rdf:JSON ;
                                cwl:type <file:///github/workspace/string[]> ] ;
                        cwl:epsg [ rdfs:label "EPSG code"^^xsd:string ;
                                rdfs:comment "EPSG code"^^xsd:string ;
                                cwl:default "\"EPSG:4326\""^^rdf:JSON ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:stac_items [ rdfs:label "Sentinel-2 STAC items"^^xsd:string ;
                                rdfs:comment "list of Sentinel-2 COG STAC items"^^xsd:string ;
                                cwl:type <file:///github/workspace/string[]> ] ] ) ;
            cwl:output ( [ dct:identifier <file:///github/workspace/stac_catalog> ;
                        cwl:outputSource <file:///github/workspace/node_stac/stac_catalog> ;
                        cwl:type <file:///github/workspace/Directory> ] ) ;
            cwl:requirements [ ns1:type <file:///github/workspace/SubworkflowFeatureRequirement> ],
                [ ns1:type <file:///github/workspace/ScatterFeatureRequirement> ],
                [ cwl:types [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml> ] ;
                    ns1:type <file:///github/workspace/SchemaDefRequirement> ] ;
            cwl:steps [ cwl:node_stac [ cwl:in [ cwl:item "stac_items" ;
                                    cwl:rasters [ cwl:source <file:///github/workspace/node_water_bodies/detected_water_body> ] ] ;
                            cwl:out ( "stac_catalog" ) ;
                            cwl:run <file:///github/workspace/#stac> ] ;
                    cwl:node_water_bodies [ cwl:in [ cwl:aoi "aoi" ;
                                    cwl:bands "bands" ;
                                    cwl:epsg "epsg" ;
                                    cwl:item "stac_items" ] ;
                            cwl:out ( "detected_water_body" ) ;
                            cwl:run <file:///github/workspace/#detect_water_body> ;
                            cwl:scatter ( "item" ) ;
                            cwl:scatterMethod <file:///github/workspace/dotproduct> ] ] ;
            ns1:type <file:///github/workspace/Workflow> ],
        [ dct:identifier <file:///github/workspace/stac> ;
            cwl:arguments () ;
            cwl:baseCommand "[\"python\",\"-m\",\"app\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "cr.terradue.com/earthquake-monitoring/stac:latest"^^xsd:string ] ] ;
            cwl:input ( [ cwl:item [ cwl:type [ cwl:inputBinding [ cwl:prefix "--input-item"^^xsd:string ] ;
                                        cwl:items <file:///github/workspace/string> ;
                                        cwl:type <file:///github/workspace/array> ] ] ;
                        cwl:rasters [ cwl:type [ cwl:inputBinding [ cwl:prefix "--water-body"^^xsd:string ] ;
                                        cwl:items <file:///github/workspace/File> ;
                                        cwl:type <file:///github/workspace/array> ] ] ] ) ;
            cwl:output ( [ cwl:stac_catalog [ cwl:outputBinding [ cwl:glob "."^^xsd:string ] ;
                                cwl:type <file:///github/workspace/Directory> ] ] ) ;
            cwl:requirements [ cwl:EnvVarRequirement [ cwl:envDef [ cwl:PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" ;
                                    cwl:PYTHONPATH "/app" ] ] ;
                    cwl:InlineJavascriptRequirement [ ] ;
                    cwl:ResourceRequirement [ cwl:coresMax 1 ;
                            cwl:ramMax 512 ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ dct:identifier <file:///github/workspace/otsu> ;
            cwl:arguments () ;
            cwl:baseCommand "[\"python\",\"-m\",\"app\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "cr.terradue.com/earthquake-monitoring/otsu:latest"^^xsd:string ] ] ;
            cwl:input ( [ cwl:raster [ cwl:inputBinding [ cwl:position "1"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:output ( [ cwl:binary_mask_item [ cwl:outputBinding [ cwl:glob "*.tif"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:requirements [ cwl:EnvVarRequirement [ cwl:envDef [ cwl:PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" ;
                                    cwl:PYTHONPATH "/app" ] ] ;
                    cwl:InlineJavascriptRequirement [ ] ;
                    cwl:ResourceRequirement [ cwl:coresMax 1 ;
                            cwl:ramMax 512 ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ dct:identifier <file:///github/workspace/crop> ;
            cwl:arguments () ;
            cwl:baseCommand "[\"python\",\"-m\",\"app\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "cr.terradue.com/earthquake-monitoring/crop:latest"^^xsd:string ] ] ;
            cwl:input ( [ cwl:aoi [ cwl:inputBinding [ cwl:prefix "--aoi"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:band [ cwl:inputBinding [ cwl:prefix "--band"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:epsg [ cwl:inputBinding [ cwl:prefix "--epsg"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:item [ cwl:inputBinding [ cwl:prefix "--input-item"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/string> ] ] ) ;
            cwl:output ( [ cwl:cropped [ cwl:outputBinding [ cwl:glob "*.tif"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:requirements [ cwl:EnvVarRequirement [ cwl:envDef [ cwl:PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" ;
                                    cwl:PYTHONPATH "/app" ] ] ;
                    cwl:InlineJavascriptRequirement [ ] ;
                    cwl:ResourceRequirement [ cwl:coresMax 1 ;
                            cwl:ramMax 512 ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ dct:identifier <file:///github/workspace/norm_diff> ;
            cwl:arguments () ;
            cwl:baseCommand "[\"python\",\"-m\",\"app\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "cr.terradue.com/earthquake-monitoring/norm_diff:latest"^^xsd:string ] ] ;
            cwl:input ( [ cwl:rasters [ cwl:inputBinding [ cwl:position "1"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File[]> ] ] ) ;
            cwl:output ( [ cwl:ndwi [ cwl:outputBinding [ cwl:glob "*.tif"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:requirements [ cwl:EnvVarRequirement [ cwl:envDef [ cwl:PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" ;
                                    cwl:PYTHONPATH "/app" ] ] ;
                    cwl:InlineJavascriptRequirement [ ] ;
                    cwl:ResourceRequirement [ cwl:coresMax 1 ;
                            cwl:ramMax 512 ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ rdfs:label "Water body detection based on NDWI and otsu threshold"^^xsd:string ;
            dct:identifier <file:///github/workspace/detect_water_body> ;
            rdfs:comment "Water body detection based on NDWI and otsu threshold"^^xsd:string ;
            cwl:input ( [ cwl:aoi [ rdfs:comment "area of interest as a bounding box"^^xsd:string ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:bands [ rdfs:comment "bands used for the NDWI"^^xsd:string ;
                                cwl:type <file:///github/workspace/string[]> ] ;
                        cwl:epsg [ rdfs:comment "EPSG code"^^xsd:string ;
                                cwl:default "\"EPSG:4326\""^^rdf:JSON ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:item [ rdfs:comment "STAC item"^^xsd:string ;
                                cwl:type <file:///github/workspace/string> ] ] ) ;
            cwl:output ( [ dct:identifier <file:///github/workspace/detected_water_body> ;
                        cwl:outputSource <file:///github/workspace/node_otsu/binary_mask_item> ;
                        cwl:type <file:///github/workspace/File> ] ) ;
            cwl:requirements [ ns1:type <file:///github/workspace/ScatterFeatureRequirement> ] ;
            cwl:steps [ cwl:node_crop [ cwl:in [ cwl:aoi "aoi" ;
                                    cwl:band "bands" ;
                                    cwl:epsg "epsg" ;
                                    cwl:item "item" ] ;
                            cwl:out ( "cropped" ) ;
                            cwl:run <file:///github/workspace/#crop> ;
                            cwl:scatter ( "band" ) ;
                            cwl:scatterMethod <file:///github/workspace/dotproduct> ] ;
                    cwl:node_normalized_difference [ cwl:in [ cwl:rasters [ cwl:source <file:///github/workspace/node_crop/cropped> ] ] ;
                            cwl:out ( "ndwi" ) ;
                            cwl:run <file:///github/workspace/#norm_diff> ] ;
                    cwl:node_otsu [ cwl:in [ cwl:raster [ cwl:source <file:///github/workspace/node_normalized_difference/ndwi> ] ] ;
                            cwl:out ( "binary_mask_item" ) ;
                            cwl:run <file:///github/workspace/#otsu> ] ] ;
            ns1:type <file:///github/workspace/Workflow> ] ;
    cwl:namespaces "{\"s\":\"https://schema.org/\"}"^^rdf:JSON ;
    cwl:schemas "http://schema.org/version/9.0/schemaorg-current-http.rdf" ;
    ns2:softwareVersion "1.4.1" .


```


### Mangrove Workflow OSPD 2025
#### yaml
```yaml
#!/usr/bin/env cwl-runner

$graph:

  - class: CommandLineTool
    id: parse_aoi
    baseCommand: echo
    arguments:
    - --
    requirements:
      InlineJavascriptRequirement: {}
      SchemaDefRequirement:
        types:
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml
      ResourceRequirement:
        coresMax: 1
        ramMax: 512

    hints:
      DockerRequirement:
        dockerPull: alpine:3.22.2

    inputs:
      aoi:
        type: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox
        label: "Area of interest"
        doc: "Area of interest defined as a bounding box"
    outputs:
      west:
        type: float
        outputBinding:
          outputEval: $(inputs.aoi.bbox[0])
      south:
        type: float
        outputBinding:
          outputEval: $(inputs.aoi.bbox[1])
      east:
        type: float
        outputBinding:
          outputEval: $(inputs.aoi.bbox[2])
      north:
        type: float
        outputBinding:
          outputEval: $(inputs.aoi.bbox[3])
      output_dir:
        type: string
        outputBinding:
          outputEval: $("outputs")

  - class: Workflow
    id: mangrove-workflow
    label: Mangrove Biomass Workflow
    doc: |
      Workflow for Mangrove Biomass Analysis
        
      This workflow orchestrates the mangrove biomass estimation process using
      Sentinel-2 imagery. It wraps the mangrove_workflow.cwl tool to provide
      a reusable workflow for analyzing different study areas.
    requirements:
      StepInputExpressionRequirement: {}
      ScatterFeatureRequirement: {}
      SubworkflowFeatureRequirement: {}
      InlineJavascriptRequirement: {}
      SchemaDefRequirement:
        types:
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml
    inputs:
      cloud_cover_max:
        label: Maximum Cloud Cover
        doc: Maximum acceptable cloud cover percentage (0-100)
        type: float
      days_back:
        label: Days Back
        doc: Number of days to search backwards from current date
        type: int
      aoi:
        label: Area of Interest
        doc: Area of interest as a bounding box
        type: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox

    outputs:
      stac:
        type: Directory
        outputSource:
          - step_1/result
    steps:
      parse_aoi:
        run: '#parse_aoi'
        in:
          aoi: aoi
        out:
          - west
          - south
          - east
          - north
          - output_dir
      step_1:
        in:
          cloud_cover_max: cloud_cover_max
          days_back: days_back
          south: parse_aoi/south
          west: parse_aoi/west
          east: parse_aoi/east
          north: parse_aoi/north
          output_dir: parse_aoi/output_dir
        run: '#mangrove_cli'
        out:
          - result

  # The content below defines the mangrove_cli CommandLineTool
  # It results from the mangrove_workflow_for_cwl.cwl jupyter 
  # notebook conversion using the ipython2cwl tool.
  - id: mangrove_cli
    arguments:
    - --
    baseCommand: /app/cwl/bin/mangrove_workflow_for_cwl
    class: CommandLineTool
    requirements:
      InlineJavascriptRequirement: {}
      ResourceRequirement:
        coresMax: 1
        ramMax: 512

    hints:
      DockerRequirement:
        dockerPull: ghcr.io/geolabs/kindgrove/mangrove-cwl:v0.0.1-rc7

    inputs:
      cloud_cover_max:
        inputBinding:
          prefix: --cloud_cover_max
        type: float
      days_back:
        inputBinding:
          prefix: --days_back
        type: int
      east:
        inputBinding: 
          prefix: --east
        type: float
      north:
        inputBinding:
          prefix: --north
        type: float
      south:
        inputBinding:
          prefix: --south
        type: float
      west:
        inputBinding:
          prefix: --west
        type: float
      output_dir:
        inputBinding:
          prefix: --output_dir
        type: string
    outputs:
      result:
        type: Directory
        outputBinding:
          glob: outputs

$namespaces:
  s: https://schema.org/
cwlVersion: v1.0
s:softwareVersion: 0.0.1

s:author:
  - class: s:Person
    s:name: Cameron Sajedi

s:contributor:
  - class: s:Person
    s:name: Gérald Fenoy
    s:identifier: "https://orcid.org/0000-0002-9617-8641"

s:keywords:
  - OSPD
  - mangrove
  - biomass

s:codeRepository: "https://github.com/starling-foundries/KindGrove"
s:license: "https://github.com/starling-foundries/KindGrove?tab=MIT-1-ov-file#readme"

schemas:
- http://schema.org/version/9.0/schemaorg-current-http.rdf
```

#### json
```json
{
  "$graph": [
    {
      "class": "CommandLineTool",
      "id": "parse_aoi",
      "baseCommand": "echo",
      "arguments": [
        "--"
      ],
      "requirements": {
        "InlineJavascriptRequirement": {},
        "SchemaDefRequirement": {
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml"
            }
          ]
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "alpine:3.22.2"
        }
      },
      "inputs": {
        "aoi": {
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox",
          "label": "Area of interest",
          "doc": "Area of interest defined as a bounding box"
        }
      },
      "outputs": {
        "west": {
          "type": "float",
          "outputBinding": {
            "outputEval": "$(inputs.aoi.bbox[0])"
          }
        },
        "south": {
          "type": "float",
          "outputBinding": {
            "outputEval": "$(inputs.aoi.bbox[1])"
          }
        },
        "east": {
          "type": "float",
          "outputBinding": {
            "outputEval": "$(inputs.aoi.bbox[2])"
          }
        },
        "north": {
          "type": "float",
          "outputBinding": {
            "outputEval": "$(inputs.aoi.bbox[3])"
          }
        },
        "output_dir": {
          "type": "string",
          "outputBinding": {
            "outputEval": "$(\"outputs\")"
          }
        }
      }
    },
    {
      "class": "Workflow",
      "id": "mangrove-workflow",
      "label": "Mangrove Biomass Workflow",
      "doc": "Workflow for Mangrove Biomass Analysis\n  \nThis workflow orchestrates the mangrove biomass estimation process using\nSentinel-2 imagery. It wraps the mangrove_workflow.cwl tool to provide\na reusable workflow for analyzing different study areas.\n",
      "requirements": {
        "StepInputExpressionRequirement": {},
        "ScatterFeatureRequirement": {},
        "SubworkflowFeatureRequirement": {},
        "InlineJavascriptRequirement": {},
        "SchemaDefRequirement": {
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml"
            },
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml"
            }
          ]
        }
      },
      "inputs": {
        "cloud_cover_max": {
          "label": "Maximum Cloud Cover",
          "doc": "Maximum acceptable cloud cover percentage (0-100)",
          "type": "float"
        },
        "days_back": {
          "label": "Days Back",
          "doc": "Number of days to search backwards from current date",
          "type": "int"
        },
        "aoi": {
          "label": "Area of Interest",
          "doc": "Area of interest as a bounding box",
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox"
        }
      },
      "outputs": {
        "stac": {
          "type": "Directory",
          "outputSource": [
            "step_1/result"
          ]
        }
      },
      "steps": {
        "parse_aoi": {
          "run": "#parse_aoi",
          "in": {
            "aoi": "aoi"
          },
          "out": [
            "west",
            "south",
            "east",
            "north",
            "output_dir"
          ]
        },
        "step_1": {
          "in": {
            "cloud_cover_max": "cloud_cover_max",
            "days_back": "days_back",
            "south": "parse_aoi/south",
            "west": "parse_aoi/west",
            "east": "parse_aoi/east",
            "north": "parse_aoi/north",
            "output_dir": "parse_aoi/output_dir"
          },
          "run": "#mangrove_cli",
          "out": [
            "result"
          ]
        }
      }
    },
    {
      "id": "mangrove_cli",
      "arguments": [
        "--"
      ],
      "baseCommand": "/app/cwl/bin/mangrove_workflow_for_cwl",
      "class": "CommandLineTool",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/geolabs/kindgrove/mangrove-cwl:v0.0.1-rc7"
        }
      },
      "inputs": {
        "cloud_cover_max": {
          "inputBinding": {
            "prefix": "--cloud_cover_max"
          },
          "type": "float"
        },
        "days_back": {
          "inputBinding": {
            "prefix": "--days_back"
          },
          "type": "int"
        },
        "east": {
          "inputBinding": {
            "prefix": "--east"
          },
          "type": "float"
        },
        "north": {
          "inputBinding": {
            "prefix": "--north"
          },
          "type": "float"
        },
        "south": {
          "inputBinding": {
            "prefix": "--south"
          },
          "type": "float"
        },
        "west": {
          "inputBinding": {
            "prefix": "--west"
          },
          "type": "float"
        },
        "output_dir": {
          "inputBinding": {
            "prefix": "--output_dir"
          },
          "type": "string"
        }
      },
      "outputs": {
        "result": {
          "type": "Directory",
          "outputBinding": {
            "glob": "outputs"
          }
        }
      }
    }
  ],
  "$namespaces": {
    "s": "https://schema.org/"
  },
  "cwlVersion": "v1.0",
  "s:softwareVersion": "0.0.1",
  "s:author": [
    {
      "class": "s:Person",
      "s:name": "Cameron Sajedi"
    }
  ],
  "s:contributor": [
    {
      "class": "s:Person",
      "s:name": "Gérald Fenoy",
      "s:identifier": "https://orcid.org/0000-0002-9617-8641"
    }
  ],
  "s:keywords": [
    "OSPD",
    "mangrove",
    "biomass"
  ],
  "s:codeRepository": "https://github.com/starling-foundries/KindGrove",
  "s:license": "https://github.com/starling-foundries/KindGrove?tab=MIT-1-ov-file#readme",
  "schemas": [
    "http://schema.org/version/9.0/schemaorg-current-http.rdf"
  ]
}

```

#### jsonld
```jsonld
{
  "@context": "https://geolabs.github.io/bblocks-eoap-cct/build/annotated/cct/cwl-to-ogcprocess/context.jsonld",
  "$graph": [
    {
      "class": "CommandLineTool",
      "id": "parse_aoi",
      "baseCommand": "echo",
      "arguments": [
        "--"
      ],
      "requirements": {
        "InlineJavascriptRequirement": {},
        "SchemaDefRequirement": {
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml"
            }
          ]
        },
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "alpine:3.22.2"
        }
      },
      "inputs": {
        "aoi": {
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox",
          "label": "Area of interest",
          "doc": "Area of interest defined as a bounding box"
        }
      },
      "outputs": {
        "west": {
          "type": "float",
          "outputBinding": {
            "outputEval": "$(inputs.aoi.bbox[0])"
          }
        },
        "south": {
          "type": "float",
          "outputBinding": {
            "outputEval": "$(inputs.aoi.bbox[1])"
          }
        },
        "east": {
          "type": "float",
          "outputBinding": {
            "outputEval": "$(inputs.aoi.bbox[2])"
          }
        },
        "north": {
          "type": "float",
          "outputBinding": {
            "outputEval": "$(inputs.aoi.bbox[3])"
          }
        },
        "output_dir": {
          "type": "string",
          "outputBinding": {
            "outputEval": "$(\"outputs\")"
          }
        }
      }
    },
    {
      "class": "Workflow",
      "id": "mangrove-workflow",
      "label": "Mangrove Biomass Workflow",
      "doc": "Workflow for Mangrove Biomass Analysis\n  \nThis workflow orchestrates the mangrove biomass estimation process using\nSentinel-2 imagery. It wraps the mangrove_workflow.cwl tool to provide\na reusable workflow for analyzing different study areas.\n",
      "requirements": {
        "StepInputExpressionRequirement": {},
        "ScatterFeatureRequirement": {},
        "SubworkflowFeatureRequirement": {},
        "InlineJavascriptRequirement": {},
        "SchemaDefRequirement": {
          "types": [
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml"
            },
            {
              "$import": "https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml"
            }
          ]
        }
      },
      "inputs": {
        "cloud_cover_max": {
          "label": "Maximum Cloud Cover",
          "doc": "Maximum acceptable cloud cover percentage (0-100)",
          "type": "float"
        },
        "days_back": {
          "label": "Days Back",
          "doc": "Number of days to search backwards from current date",
          "type": "int"
        },
        "aoi": {
          "label": "Area of Interest",
          "doc": "Area of interest as a bounding box",
          "type": "https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox"
        }
      },
      "outputs": {
        "stac": {
          "type": "Directory",
          "outputSource": [
            "step_1/result"
          ]
        }
      },
      "steps": {
        "parse_aoi": {
          "run": "#parse_aoi",
          "in": {
            "aoi": "aoi"
          },
          "out": [
            "west",
            "south",
            "east",
            "north",
            "output_dir"
          ]
        },
        "step_1": {
          "in": {
            "cloud_cover_max": "cloud_cover_max",
            "days_back": "days_back",
            "south": "parse_aoi/south",
            "west": "parse_aoi/west",
            "east": "parse_aoi/east",
            "north": "parse_aoi/north",
            "output_dir": "parse_aoi/output_dir"
          },
          "run": "#mangrove_cli",
          "out": [
            "result"
          ]
        }
      }
    },
    {
      "id": "mangrove_cli",
      "arguments": [
        "--"
      ],
      "baseCommand": "/app/cwl/bin/mangrove_workflow_for_cwl",
      "class": "CommandLineTool",
      "requirements": {
        "InlineJavascriptRequirement": {},
        "ResourceRequirement": {
          "coresMax": 1,
          "ramMax": 512
        }
      },
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/geolabs/kindgrove/mangrove-cwl:v0.0.1-rc7"
        }
      },
      "inputs": {
        "cloud_cover_max": {
          "inputBinding": {
            "prefix": "--cloud_cover_max"
          },
          "type": "float"
        },
        "days_back": {
          "inputBinding": {
            "prefix": "--days_back"
          },
          "type": "int"
        },
        "east": {
          "inputBinding": {
            "prefix": "--east"
          },
          "type": "float"
        },
        "north": {
          "inputBinding": {
            "prefix": "--north"
          },
          "type": "float"
        },
        "south": {
          "inputBinding": {
            "prefix": "--south"
          },
          "type": "float"
        },
        "west": {
          "inputBinding": {
            "prefix": "--west"
          },
          "type": "float"
        },
        "output_dir": {
          "inputBinding": {
            "prefix": "--output_dir"
          },
          "type": "string"
        }
      },
      "outputs": {
        "result": {
          "type": "Directory",
          "outputBinding": {
            "glob": "outputs"
          }
        }
      }
    }
  ],
  "$namespaces": {
    "s": "https://schema.org/"
  },
  "cwlVersion": "v1.0",
  "s:softwareVersion": "0.0.1",
  "s:author": [
    {
      "class": "s:Person",
      "s:name": "Cameron Sajedi"
    }
  ],
  "s:contributor": [
    {
      "class": "s:Person",
      "s:name": "G\u00e9rald Fenoy",
      "s:identifier": "https://orcid.org/0000-0002-9617-8641"
    }
  ],
  "s:keywords": [
    "OSPD",
    "mangrove",
    "biomass"
  ],
  "s:codeRepository": "https://github.com/starling-foundries/KindGrove",
  "s:license": "https://github.com/starling-foundries/KindGrove?tab=MIT-1-ov-file#readme",
  "schemas": [
    "http://schema.org/version/9.0/schemaorg-current-http.rdf"
  ]
}
```

#### ttl
```ttl
@prefix cwl: <https://w3id.org/cwl/cwl#> .
@prefix dct: <http://purl.org/dc/terms/> .
@prefix ns1: <rdf:> .
@prefix ns2: <s:> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

[] cwl:cwlVersion <file:///github/workspace/v1.0> ;
    cwl:graph [ rdfs:label "Mangrove Biomass Workflow"^^xsd:string ;
            dct:identifier <file:///github/workspace/mangrove-workflow> ;
            rdfs:comment """Workflow for Mangrove Biomass Analysis
  
This workflow orchestrates the mangrove biomass estimation process using
Sentinel-2 imagery. It wraps the mangrove_workflow.cwl tool to provide
a reusable workflow for analyzing different study areas.
"""^^xsd:string ;
            cwl:input ( [ cwl:aoi [ rdfs:label "Area of Interest"^^xsd:string ;
                                rdfs:comment "Area of interest as a bounding box"^^xsd:string ;
                                cwl:type <https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox> ] ;
                        cwl:cloud_cover_max [ rdfs:label "Maximum Cloud Cover"^^xsd:string ;
                                rdfs:comment "Maximum acceptable cloud cover percentage (0-100)"^^xsd:string ;
                                cwl:type <file:///github/workspace/float> ] ;
                        cwl:days_back [ rdfs:label "Days Back"^^xsd:string ;
                                rdfs:comment "Number of days to search backwards from current date"^^xsd:string ;
                                cwl:type <file:///github/workspace/int> ] ] ) ;
            cwl:output ( [ cwl:stac [ cwl:outputSource <file:///github/workspace/step_1/result> ;
                                cwl:type <file:///github/workspace/Directory> ] ] ) ;
            cwl:requirements [ cwl:InlineJavascriptRequirement [ ] ;
                    cwl:ScatterFeatureRequirement [ ] ;
                    cwl:SchemaDefRequirement [ cwl:types [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml> ],
                                [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/stac.yaml> ] ] ;
                    cwl:StepInputExpressionRequirement [ ] ;
                    cwl:SubworkflowFeatureRequirement [ ] ] ;
            cwl:steps [ cwl:parse_aoi [ cwl:in [ cwl:aoi "aoi" ] ;
                            cwl:out ( "west" "south" "east" "north" "output_dir" ) ;
                            cwl:run <file:///github/workspace/#parse_aoi> ] ;
                    cwl:step_1 [ cwl:in [ cwl:cloud_cover_max "cloud_cover_max" ;
                                    cwl:days_back "days_back" ;
                                    cwl:east "parse_aoi/east" ;
                                    cwl:north "parse_aoi/north" ;
                                    cwl:output_dir "parse_aoi/output_dir" ;
                                    cwl:south "parse_aoi/south" ;
                                    cwl:west "parse_aoi/west" ] ;
                            cwl:out ( "result" ) ;
                            cwl:run <file:///github/workspace/#mangrove_cli> ] ] ;
            ns1:type <file:///github/workspace/Workflow> ],
        [ dct:identifier <file:///github/workspace/mangrove_cli> ;
            cwl:arguments ( "--" ) ;
            cwl:baseCommand "\"/app/cwl/bin/mangrove_workflow_for_cwl\""^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "ghcr.io/geolabs/kindgrove/mangrove-cwl:v0.0.1-rc7"^^xsd:string ] ] ;
            cwl:input ( [ cwl:cloud_cover_max [ cwl:inputBinding [ cwl:prefix "--cloud_cover_max"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/float> ] ;
                        cwl:days_back [ cwl:inputBinding [ cwl:prefix "--days_back"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/int> ] ;
                        cwl:east [ cwl:inputBinding [ cwl:prefix "--east"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/float> ] ;
                        cwl:north [ cwl:inputBinding [ cwl:prefix "--north"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/float> ] ;
                        cwl:output_dir [ cwl:inputBinding [ cwl:prefix "--output_dir"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:south [ cwl:inputBinding [ cwl:prefix "--south"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/float> ] ;
                        cwl:west [ cwl:inputBinding [ cwl:prefix "--west"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/float> ] ] ) ;
            cwl:output ( [ cwl:result [ cwl:outputBinding [ cwl:glob "outputs"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/Directory> ] ] ) ;
            cwl:requirements [ cwl:InlineJavascriptRequirement [ ] ;
                    cwl:ResourceRequirement [ cwl:coresMax 1 ;
                            cwl:ramMax 512 ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ dct:identifier <file:///github/workspace/parse_aoi> ;
            cwl:arguments ( "--" ) ;
            cwl:baseCommand "\"echo\""^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "alpine:3.22.2"^^xsd:string ] ] ;
            cwl:input ( [ cwl:aoi [ rdfs:label "Area of interest"^^xsd:string ;
                                rdfs:comment "Area of interest defined as a bounding box"^^xsd:string ;
                                cwl:type <https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox> ] ] ) ;
            cwl:output ( [ cwl:east [ cwl:outputBinding [ cwl:outputEval "$(inputs.aoi.bbox[2])"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/float> ] ;
                        cwl:north [ cwl:outputBinding [ cwl:outputEval "$(inputs.aoi.bbox[3])"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/float> ] ;
                        cwl:output_dir [ cwl:outputBinding [ cwl:outputEval "$(\"outputs\")"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:south [ cwl:outputBinding [ cwl:outputEval "$(inputs.aoi.bbox[1])"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/float> ] ;
                        cwl:west [ cwl:outputBinding [ cwl:outputEval "$(inputs.aoi.bbox[0])"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/float> ] ] ) ;
            cwl:requirements [ cwl:InlineJavascriptRequirement [ ] ;
                    cwl:ResourceRequirement [ cwl:coresMax 1 ;
                            cwl:ramMax 512 ] ;
                    cwl:SchemaDefRequirement [ cwl:types [ cwl:import <https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml> ] ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ] ;
    cwl:namespaces "{\"s\":\"https://schema.org/\"}"^^rdf:JSON ;
    cwl:schemas "http://schema.org/version/9.0/schemaorg-current-http.rdf" ;
    ns2:author [ ns1:type ns2:Person ;
            ns2:name "Cameron Sajedi" ] ;
    ns2:codeRepository "https://github.com/starling-foundries/KindGrove" ;
    ns2:contributor [ ns1:type ns2:Person ;
            ns2:identifier "https://orcid.org/0000-0002-9617-8641" ;
            ns2:name "Gérald Fenoy" ] ;
    ns2:keywords "OSPD",
        "biomass",
        "mangrove" ;
    ns2:license "https://github.com/starling-foundries/KindGrove?tab=MIT-1-ov-file#readme" ;
    ns2:softwareVersion "0.0.1" .


```


### Hartis CVI Workflow OSPD 2025
#### yaml
```yaml
cwlVersion: v1.2

$namespaces:
  s: https://schema.org/

$schemas:
  - http://schema.org/version/latest/schemaorg-current-http.rdf

$graph:
  - class: Workflow
    id: cvi-workflow
    label: CVI Workflow (Dockerized)
    doc: |
      This workflow computes the Coastal Vulnerability Index (CVI) for Mediterranean coastal areas.
      It processes coastline data, generates transects, computes various coastal parameters
      (landcover, slope, erosion, elevation), and calculates the final CVI values.
    
    requirements:
      StepInputExpressionRequirement: {}
      InlineJavascriptRequirement: {}
    
    s:author:
      - class: s:Person
        s:name: HARTIS Organization
        s:url: https://github.com/hartis-org
    
    s:codeRepository: https://github.com/hartis-org/cvi-workflow
    s:dateCreated: "2024-01-01"
    s:license: https://opensource.org/licenses/MIT
    s:version: "1.0.0"
    s:keywords: CVI, coastal vulnerability, Mediterranean, earth observation
    
    inputs:
      config_stac_item_url:
        type: string
        label: Configuration STAC item URL
        doc: URL of the STAC item containing the configuration JSON file
        default: "https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/cvi-scoring-configuration"
      
      aois_stac_item_url:
        type: string
        label: AOIs STAC item URL
        doc: URL of the STAC item containing the Mediterranean AOIs CSV file
        default: "https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/mediterranean-coastal-aois"
      
      tokens_stac_item_url:
        type: string
        label: Tokens STAC item URL
        doc: URL of the STAC item containing the authentication tokens file
        default: "https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/cvi-authentication-template"
    
    outputs:
      validated_config:
        type: File
        label: Validated configuration
        doc: Validated configuration JSON file
        outputSource: setup_env/config_validated
      
      coastline_gpkg:
        type: File
        label: Coastline GeoPackage
        doc: Extracted coastline geometry in GeoPackage format
        outputSource: extract_coastline/coastline_gpkg
      
      transects_geojson:
        type: File
        label: Generated transects
        doc: Perpendicular transects generated along the coastline
        outputSource: generate_transects/transects_geojson
      
      transects_landcover:
        type: File
        label: Transects with landcover data
        doc: Transects enriched with landcover information
        outputSource: compute_landcover/result
      
      transects_slope:
        type: File
        label: Transects with slope data
        doc: Transects enriched with slope information
        outputSource: compute_slope/result
      
      transects_erosion:
        type: File
        label: Transects with erosion data
        doc: Transects enriched with erosion information
        outputSource: compute_erosion/result
      
      transects_elevation:
        type: File
        label: Transects with elevation data
        doc: Transects enriched with elevation information
        outputSource: compute_elevation/result
      
      cvi_geojson:
        type: File
        label: CVI results
        doc: Final Coastal Vulnerability Index values for all transects
        outputSource: compute_cvi/out_geojson
    
    steps:
      node_eodag_download_config:
        label: Download configuration [EODAG]
        doc: Download the configuration JSON file from STAC item
        run: '#eodag_search'
        in:
          stac_item_url: config_stac_item_url
        out: [data_output_dir]
      
      node_eodag_download_aois:
        label: Download AOIs [EODAG]
        doc: Download the Mediterranean AOIs CSV from STAC item
        run: '#eodag_search'
        in:
          stac_item_url: aois_stac_item_url
        out: [data_output_dir]
      
      node_eodag_download_tokens:
        label: Download tokens [EODAG]
        doc: Download the authentication tokens file from STAC item
        run: '#eodag_search'
        in:
          stac_item_url: tokens_stac_item_url
        out: [data_output_dir]
      
      setup_env:
        label: Setup Environment
        run: "#setup-env-tool"
        in:
          config_json:
            source: node_eodag_download_config/data_output_dir
            valueFrom: $(self.listing.filter(function(f) { return f.basename.match(/.*\.json$/i); })[0])
          output_dir: { default: "output_data" }
        out: [config_validated]
      
      extract_coastline:
        label: Extract Coastline
        run: "#extract-coastline-tool"
        in:
          med_aois_csv:
            source: node_eodag_download_aois/data_output_dir
            valueFrom: $(self.listing.filter(function(f) { return f.basename.match(/.*\.csv$/i); })[0])
          output_dir: { default: "output_data" }
        out: [coastline_gpkg]
      
      generate_transects:
        label: Generate Transects
        run: "#generate-transects-tool"
        in:
          coastline_gpkg: extract_coastline/coastline_gpkg
          output_dir: { default: "output_data" }
        out: [transects_geojson]
      
      compute_landcover:
        label: Compute Landcover
        run: "#compute-parameter-tool"
        in:
          script: { default: "/app/steps/compute_landcover.py" }
          transects_geojson: generate_transects/transects_geojson
          tokens_env:
            source: node_eodag_download_tokens/data_output_dir
            valueFrom: $(self.listing.filter(function(f) { return f.basename.match(/.*\.env$/i); })[0])
          config_json: setup_env/config_validated
          output_dir: { default: "output_data" }
        out: [result]
      
      compute_slope:
        label: Compute Slope
        run: "#compute-parameter-tool"
        in:
          script: { default: "/app/steps/compute_slope.py" }
          transects_geojson: generate_transects/transects_geojson
          tokens_env:
            source: node_eodag_download_tokens/data_output_dir
            valueFrom: $(self.listing.filter(function(f) { return f.basename.match(/.*\.env$/i); })[0])
          config_json: setup_env/config_validated
          output_dir: { default: "output_data" }
        out: [result]
      
      compute_erosion:
        label: Compute Erosion
        run: "#compute-parameter-tool"
        in:
          script: { default: "/app/steps/compute_erosion.py" }
          transects_geojson: generate_transects/transects_geojson
          tokens_env:
            source: node_eodag_download_tokens/data_output_dir
            valueFrom: $(self.listing.filter(function(f) { return f.basename.match(/.*\.env$/i); })[0])
          config_json: setup_env/config_validated
          output_dir: { default: "output_data" }
        out: [result]
      
      compute_elevation:
        label: Compute Elevation
        run: "#compute-parameter-tool"
        in:
          script: { default: "/app/steps/compute_elevation.py" }
          transects_geojson: generate_transects/transects_geojson
          tokens_env:
            source: node_eodag_download_tokens/data_output_dir
            valueFrom: $(self.listing.filter(function(f) { return f.basename.match(/.*\.env$/i); })[0])
          config_json: setup_env/config_validated
          output_dir: { default: "output_data" }
        out: [result]
      
      compute_cvi:
        label: Compute CVI Index
        run: "#compute-cvi-tool"
        in:
          transects_landcover: compute_landcover/result
          transects_slope: compute_slope/result
          transects_erosion: compute_erosion/result
          transects_elevation: compute_elevation/result
          config_json: setup_env/config_validated
          output_dir: { default: "output_data" }
        out: [out_geojson]
  
  # CommandLineTool definitions
  - class: CommandLineTool
    id: setup-env-tool
    label: Setup Environment
    doc: Validates configuration and initializes the working environment
    
    baseCommand: [python3, /app/steps/setup_env.py]
    
    hints:
      DockerRequirement: &docker_image
        dockerPull: ghcr.io/hartis-org/cvi-workflow:latest
    
    requirements:
      InlineJavascriptRequirement: {}
      InitialWorkDirRequirement:
        listing:
          - $(inputs.config_json)
          - { entry: "$({class: 'Directory', listing: []})", entryname: $(inputs.output_dir), writable: true }
    
    inputs:
      config_json:
        type: File
        inputBinding:
          position: 1
        doc: Configuration JSON file
      
      output_dir:
        type: string
        inputBinding:
          position: 2
        doc: Output directory path
    
    outputs:
      config_validated:
        type: File
        outputBinding:
          glob: "$(inputs.output_dir)/config_validated.json"
        doc: Validated configuration file
  
  - class: CommandLineTool
    id: extract-coastline-tool
    label: Extract Coastline
    doc: Extracts coastline geometry from Mediterranean AOIs
    
    baseCommand: [python3, /app/steps/extract_coastline.py]
    
    hints:
      DockerRequirement: *docker_image
    
    requirements:
      InlineJavascriptRequirement: {}
      InitialWorkDirRequirement:
        listing:
          - $(inputs.med_aois_csv)
          - { entry: "$({class: 'Directory', listing: []})", entryname: $(inputs.output_dir), writable: true }
    
    inputs:
      med_aois_csv:
        type: File
        inputBinding:
          position: 1
        doc: Mediterranean areas of interest CSV
      
      output_dir:
        type: string
        inputBinding:
          position: 2
        doc: Output directory path
    
    outputs:
      coastline_gpkg:
        type: File
        outputBinding:
          glob: "$(inputs.output_dir)/coastline.gpkg"
        doc: Extracted coastline GeoPackage
  
  - class: CommandLineTool
    id: generate-transects-tool
    label: Generate Transects
    doc: Generates perpendicular transects along the coastline
    
    baseCommand: [python3, /app/steps/generate_transects.py]
    
    hints:
      DockerRequirement: *docker_image
    
    requirements:
      InlineJavascriptRequirement: {}
      InitialWorkDirRequirement:
        listing:
          - $(inputs.coastline_gpkg)
          - { entry: "$({class: 'Directory', listing: []})", entryname: $(inputs.output_dir), writable: true }
    
    inputs:
      coastline_gpkg:
        type: File
        inputBinding:
          position: 1
        doc: Coastline GeoPackage
      
      output_dir:
        type: string
        inputBinding:
          position: 2
        doc: Output directory path
    
    outputs:
      transects_geojson:
        type: File
        outputBinding:
          glob: "$(inputs.output_dir)/transects.geojson"
        doc: Generated transects GeoJSON
  
  - class: CommandLineTool
    id: compute-parameter-tool
    label: Compute Parameter
    doc: Computes a CVI parameter (landcover, slope, erosion, or elevation) for transects
    
    baseCommand: [python3]
    
    hints:
      DockerRequirement: *docker_image
    
    requirements:
      InlineJavascriptRequirement: {}
      InitialWorkDirRequirement:
        listing:
          - entry: $(inputs.transects_geojson)
          - entry: $(inputs.tokens_env)
          - entry: $(inputs.config_json)
          - entry: "$({class: 'Directory', listing: []})"
            entryname: $(inputs.output_dir)
            writable: true
    
    inputs:
      script:
        type: string
        inputBinding:
          position: 0
        doc: Python script path for parameter computation
      
      transects_geojson:
        type: File
        inputBinding:
          position: 1
        doc: Transects GeoJSON file
      
      tokens_env:
        type: File
        inputBinding:
          position: 2
        doc: Authentication tokens file
      
      config_json:
        type: File
        inputBinding:
          position: 3
        doc: Configuration JSON file
      
      output_dir:
        type: string
        inputBinding:
          position: 4
        doc: Output directory path
    
    outputs:
      result:
        type: File
        outputBinding:
          glob: "$(inputs.output_dir)/*.geojson"
        doc: Transects enriched with parameter data
  
  - class: CommandLineTool
    id: compute-cvi-tool
    label: Compute CVI
    doc: Computes final Coastal Vulnerability Index from all parameters
    
    baseCommand: [python3, /app/steps/compute_cvi.py]
    
    hints:
      DockerRequirement: *docker_image
    
    requirements:
      InlineJavascriptRequirement: {}
      InitialWorkDirRequirement:
        listing:
          - $(inputs.transects_landcover)
          - $(inputs.transects_slope)
          - $(inputs.transects_erosion)
          - $(inputs.transects_elevation)
          - $(inputs.config_json)
          - { entry: "$({class: 'Directory', listing: []})", entryname: $(inputs.output_dir), writable: true }
    
    inputs:
      transects_landcover:
        type: File
        inputBinding:
          position: 1
        doc: Transects with landcover data
      
      transects_slope:
        type: File
        inputBinding:
          position: 2
        doc: Transects with slope data
      
      transects_erosion:
        type: File
        inputBinding:
          position: 3
        doc: Transects with erosion data
      
      transects_elevation:
        type: File
        inputBinding:
          position: 4
        doc: Transects with elevation data
      
      config_json:
        type: File
        inputBinding:
          position: 5
        doc: Configuration JSON file
      
      output_dir:
        type: string
        inputBinding:
          position: 6
        doc: Output directory path
    
    outputs:
      out_geojson:
        type: File
        outputBinding:
          glob: "$(inputs.output_dir)/transects_with_cvi_equal.geojson"
        doc: Final CVI results GeoJSON

  - class: CommandLineTool
    id: eodag_search
    label: Download input data
    doc: Downloads STAC item assets using EODAG
    
    s:softwareVersion: latest
    
    hints:
      DockerRequirement:
        dockerPull: |-
          ghcr.io/cs-si/eodag:v3.10.x
    
    requirements:
      InlineJavascriptRequirement: {}
      NetworkAccess:
        networkAccess: true
    
    baseCommand: [eodag, download]
    
    arguments:
      - prefix: "--output-dir"
        valueFrom: $(runtime.outdir)
    
    inputs:
      stac_item_url:
        type: string
        inputBinding:
          prefix: "--stac-item"
        doc: URL of the STAC item to download
    
    outputs:
      data_output_dir:
        type: Directory
        outputBinding:
          glob: $(runtime.outdir)/*
        doc: Directory containing downloaded STAC item assets
```

#### json
```json
{
  "cwlVersion": "v1.2",
  "$namespaces": {
    "s": "https://schema.org/"
  },
  "$schemas": [
    "http://schema.org/version/latest/schemaorg-current-http.rdf"
  ],
  "$graph": [
    {
      "class": "Workflow",
      "id": "cvi-workflow",
      "label": "CVI Workflow (Dockerized)",
      "doc": "This workflow computes the Coastal Vulnerability Index (CVI) for Mediterranean coastal areas.\nIt processes coastline data, generates transects, computes various coastal parameters\n(landcover, slope, erosion, elevation), and calculates the final CVI values.\n",
      "requirements": {
        "StepInputExpressionRequirement": {},
        "InlineJavascriptRequirement": {}
      },
      "s:author": [
        {
          "class": "s:Person",
          "s:name": "HARTIS Organization",
          "s:url": "https://github.com/hartis-org"
        }
      ],
      "s:codeRepository": "https://github.com/hartis-org/cvi-workflow",
      "s:dateCreated": "2024-01-01",
      "s:license": "https://opensource.org/licenses/MIT",
      "s:version": "1.0.0",
      "s:keywords": "CVI, coastal vulnerability, Mediterranean, earth observation",
      "inputs": {
        "config_stac_item_url": {
          "type": "string",
          "label": "Configuration STAC item URL",
          "doc": "URL of the STAC item containing the configuration JSON file",
          "default": "https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/cvi-scoring-configuration"
        },
        "aois_stac_item_url": {
          "type": "string",
          "label": "AOIs STAC item URL",
          "doc": "URL of the STAC item containing the Mediterranean AOIs CSV file",
          "default": "https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/mediterranean-coastal-aois"
        },
        "tokens_stac_item_url": {
          "type": "string",
          "label": "Tokens STAC item URL",
          "doc": "URL of the STAC item containing the authentication tokens file",
          "default": "https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/cvi-authentication-template"
        }
      },
      "outputs": {
        "validated_config": {
          "type": "File",
          "label": "Validated configuration",
          "doc": "Validated configuration JSON file",
          "outputSource": "setup_env/config_validated"
        },
        "coastline_gpkg": {
          "type": "File",
          "label": "Coastline GeoPackage",
          "doc": "Extracted coastline geometry in GeoPackage format",
          "outputSource": "extract_coastline/coastline_gpkg"
        },
        "transects_geojson": {
          "type": "File",
          "label": "Generated transects",
          "doc": "Perpendicular transects generated along the coastline",
          "outputSource": "generate_transects/transects_geojson"
        },
        "transects_landcover": {
          "type": "File",
          "label": "Transects with landcover data",
          "doc": "Transects enriched with landcover information",
          "outputSource": "compute_landcover/result"
        },
        "transects_slope": {
          "type": "File",
          "label": "Transects with slope data",
          "doc": "Transects enriched with slope information",
          "outputSource": "compute_slope/result"
        },
        "transects_erosion": {
          "type": "File",
          "label": "Transects with erosion data",
          "doc": "Transects enriched with erosion information",
          "outputSource": "compute_erosion/result"
        },
        "transects_elevation": {
          "type": "File",
          "label": "Transects with elevation data",
          "doc": "Transects enriched with elevation information",
          "outputSource": "compute_elevation/result"
        },
        "cvi_geojson": {
          "type": "File",
          "label": "CVI results",
          "doc": "Final Coastal Vulnerability Index values for all transects",
          "outputSource": "compute_cvi/out_geojson"
        }
      },
      "steps": {
        "node_eodag_download_config": {
          "label": "Download configuration [EODAG]",
          "doc": "Download the configuration JSON file from STAC item",
          "run": "#eodag_search",
          "in": {
            "stac_item_url": "config_stac_item_url"
          },
          "out": [
            "data_output_dir"
          ]
        },
        "node_eodag_download_aois": {
          "label": "Download AOIs [EODAG]",
          "doc": "Download the Mediterranean AOIs CSV from STAC item",
          "run": "#eodag_search",
          "in": {
            "stac_item_url": "aois_stac_item_url"
          },
          "out": [
            "data_output_dir"
          ]
        },
        "node_eodag_download_tokens": {
          "label": "Download tokens [EODAG]",
          "doc": "Download the authentication tokens file from STAC item",
          "run": "#eodag_search",
          "in": {
            "stac_item_url": "tokens_stac_item_url"
          },
          "out": [
            "data_output_dir"
          ]
        },
        "setup_env": {
          "label": "Setup Environment",
          "run": "#setup-env-tool",
          "in": {
            "config_json": {
              "source": "node_eodag_download_config/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.json$/i); })[0])"
            },
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "config_validated"
          ]
        },
        "extract_coastline": {
          "label": "Extract Coastline",
          "run": "#extract-coastline-tool",
          "in": {
            "med_aois_csv": {
              "source": "node_eodag_download_aois/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.csv$/i); })[0])"
            },
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "coastline_gpkg"
          ]
        },
        "generate_transects": {
          "label": "Generate Transects",
          "run": "#generate-transects-tool",
          "in": {
            "coastline_gpkg": "extract_coastline/coastline_gpkg",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "transects_geojson"
          ]
        },
        "compute_landcover": {
          "label": "Compute Landcover",
          "run": "#compute-parameter-tool",
          "in": {
            "script": {
              "default": "/app/steps/compute_landcover.py"
            },
            "transects_geojson": "generate_transects/transects_geojson",
            "tokens_env": {
              "source": "node_eodag_download_tokens/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"
            },
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "result"
          ]
        },
        "compute_slope": {
          "label": "Compute Slope",
          "run": "#compute-parameter-tool",
          "in": {
            "script": {
              "default": "/app/steps/compute_slope.py"
            },
            "transects_geojson": "generate_transects/transects_geojson",
            "tokens_env": {
              "source": "node_eodag_download_tokens/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"
            },
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "result"
          ]
        },
        "compute_erosion": {
          "label": "Compute Erosion",
          "run": "#compute-parameter-tool",
          "in": {
            "script": {
              "default": "/app/steps/compute_erosion.py"
            },
            "transects_geojson": "generate_transects/transects_geojson",
            "tokens_env": {
              "source": "node_eodag_download_tokens/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"
            },
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "result"
          ]
        },
        "compute_elevation": {
          "label": "Compute Elevation",
          "run": "#compute-parameter-tool",
          "in": {
            "script": {
              "default": "/app/steps/compute_elevation.py"
            },
            "transects_geojson": "generate_transects/transects_geojson",
            "tokens_env": {
              "source": "node_eodag_download_tokens/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"
            },
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "result"
          ]
        },
        "compute_cvi": {
          "label": "Compute CVI Index",
          "run": "#compute-cvi-tool",
          "in": {
            "transects_landcover": "compute_landcover/result",
            "transects_slope": "compute_slope/result",
            "transects_erosion": "compute_erosion/result",
            "transects_elevation": "compute_elevation/result",
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "out_geojson"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "setup-env-tool",
      "label": "Setup Environment",
      "doc": "Validates configuration and initializes the working environment",
      "baseCommand": [
        "python3",
        "/app/steps/setup_env.py"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            "$(inputs.config_json)",
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "config_json": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Configuration JSON file"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 2
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "config_validated": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/config_validated.json"
          },
          "doc": "Validated configuration file"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "extract-coastline-tool",
      "label": "Extract Coastline",
      "doc": "Extracts coastline geometry from Mediterranean AOIs",
      "baseCommand": [
        "python3",
        "/app/steps/extract_coastline.py"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            "$(inputs.med_aois_csv)",
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "med_aois_csv": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Mediterranean areas of interest CSV"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 2
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "coastline_gpkg": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/coastline.gpkg"
          },
          "doc": "Extracted coastline GeoPackage"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "generate-transects-tool",
      "label": "Generate Transects",
      "doc": "Generates perpendicular transects along the coastline",
      "baseCommand": [
        "python3",
        "/app/steps/generate_transects.py"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            "$(inputs.coastline_gpkg)",
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "coastline_gpkg": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Coastline GeoPackage"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 2
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "transects_geojson": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/transects.geojson"
          },
          "doc": "Generated transects GeoJSON"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "compute-parameter-tool",
      "label": "Compute Parameter",
      "doc": "Computes a CVI parameter (landcover, slope, erosion, or elevation) for transects",
      "baseCommand": [
        "python3"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            {
              "entry": "$(inputs.transects_geojson)"
            },
            {
              "entry": "$(inputs.tokens_env)"
            },
            {
              "entry": "$(inputs.config_json)"
            },
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "script": {
          "type": "string",
          "inputBinding": {
            "position": 0
          },
          "doc": "Python script path for parameter computation"
        },
        "transects_geojson": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Transects GeoJSON file"
        },
        "tokens_env": {
          "type": "File",
          "inputBinding": {
            "position": 2
          },
          "doc": "Authentication tokens file"
        },
        "config_json": {
          "type": "File",
          "inputBinding": {
            "position": 3
          },
          "doc": "Configuration JSON file"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 4
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "result": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/*.geojson"
          },
          "doc": "Transects enriched with parameter data"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "compute-cvi-tool",
      "label": "Compute CVI",
      "doc": "Computes final Coastal Vulnerability Index from all parameters",
      "baseCommand": [
        "python3",
        "/app/steps/compute_cvi.py"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            "$(inputs.transects_landcover)",
            "$(inputs.transects_slope)",
            "$(inputs.transects_erosion)",
            "$(inputs.transects_elevation)",
            "$(inputs.config_json)",
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "transects_landcover": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Transects with landcover data"
        },
        "transects_slope": {
          "type": "File",
          "inputBinding": {
            "position": 2
          },
          "doc": "Transects with slope data"
        },
        "transects_erosion": {
          "type": "File",
          "inputBinding": {
            "position": 3
          },
          "doc": "Transects with erosion data"
        },
        "transects_elevation": {
          "type": "File",
          "inputBinding": {
            "position": 4
          },
          "doc": "Transects with elevation data"
        },
        "config_json": {
          "type": "File",
          "inputBinding": {
            "position": 5
          },
          "doc": "Configuration JSON file"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 6
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "out_geojson": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/transects_with_cvi_equal.geojson"
          },
          "doc": "Final CVI results GeoJSON"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "eodag_search",
      "label": "Download input data",
      "doc": "Downloads STAC item assets using EODAG",
      "s:softwareVersion": "latest",
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/cs-si/eodag:v3.10.x"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "NetworkAccess": {
          "networkAccess": true
        }
      },
      "baseCommand": [
        "eodag",
        "download"
      ],
      "arguments": [
        {
          "prefix": "--output-dir",
          "valueFrom": "$(runtime.outdir)"
        }
      ],
      "inputs": {
        "stac_item_url": {
          "type": "string",
          "inputBinding": {
            "prefix": "--stac-item"
          },
          "doc": "URL of the STAC item to download"
        }
      },
      "outputs": {
        "data_output_dir": {
          "type": "Directory",
          "outputBinding": {
            "glob": "$(runtime.outdir)/*"
          },
          "doc": "Directory containing downloaded STAC item assets"
        }
      }
    }
  ]
}

```

#### jsonld
```jsonld
{
  "@context": "https://geolabs.github.io/bblocks-eoap-cct/build/annotated/cct/cwl-to-ogcprocess/context.jsonld",
  "cwlVersion": "v1.2",
  "$namespaces": {
    "s": "https://schema.org/"
  },
  "$schemas": [
    "http://schema.org/version/latest/schemaorg-current-http.rdf"
  ],
  "$graph": [
    {
      "class": "Workflow",
      "id": "cvi-workflow",
      "label": "CVI Workflow (Dockerized)",
      "doc": "This workflow computes the Coastal Vulnerability Index (CVI) for Mediterranean coastal areas.\nIt processes coastline data, generates transects, computes various coastal parameters\n(landcover, slope, erosion, elevation), and calculates the final CVI values.\n",
      "requirements": {
        "StepInputExpressionRequirement": {},
        "InlineJavascriptRequirement": {}
      },
      "s:author": [
        {
          "class": "s:Person",
          "s:name": "HARTIS Organization",
          "s:url": "https://github.com/hartis-org"
        }
      ],
      "s:codeRepository": "https://github.com/hartis-org/cvi-workflow",
      "s:dateCreated": "2024-01-01",
      "s:license": "https://opensource.org/licenses/MIT",
      "s:version": "1.0.0",
      "s:keywords": "CVI, coastal vulnerability, Mediterranean, earth observation",
      "inputs": {
        "config_stac_item_url": {
          "type": "string",
          "label": "Configuration STAC item URL",
          "doc": "URL of the STAC item containing the configuration JSON file",
          "default": "https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/cvi-scoring-configuration"
        },
        "aois_stac_item_url": {
          "type": "string",
          "label": "AOIs STAC item URL",
          "doc": "URL of the STAC item containing the Mediterranean AOIs CSV file",
          "default": "https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/mediterranean-coastal-aois"
        },
        "tokens_stac_item_url": {
          "type": "string",
          "label": "Tokens STAC item URL",
          "doc": "URL of the STAC item containing the authentication tokens file",
          "default": "https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/cvi-authentication-template"
        }
      },
      "outputs": {
        "validated_config": {
          "type": "File",
          "label": "Validated configuration",
          "doc": "Validated configuration JSON file",
          "outputSource": "setup_env/config_validated"
        },
        "coastline_gpkg": {
          "type": "File",
          "label": "Coastline GeoPackage",
          "doc": "Extracted coastline geometry in GeoPackage format",
          "outputSource": "extract_coastline/coastline_gpkg"
        },
        "transects_geojson": {
          "type": "File",
          "label": "Generated transects",
          "doc": "Perpendicular transects generated along the coastline",
          "outputSource": "generate_transects/transects_geojson"
        },
        "transects_landcover": {
          "type": "File",
          "label": "Transects with landcover data",
          "doc": "Transects enriched with landcover information",
          "outputSource": "compute_landcover/result"
        },
        "transects_slope": {
          "type": "File",
          "label": "Transects with slope data",
          "doc": "Transects enriched with slope information",
          "outputSource": "compute_slope/result"
        },
        "transects_erosion": {
          "type": "File",
          "label": "Transects with erosion data",
          "doc": "Transects enriched with erosion information",
          "outputSource": "compute_erosion/result"
        },
        "transects_elevation": {
          "type": "File",
          "label": "Transects with elevation data",
          "doc": "Transects enriched with elevation information",
          "outputSource": "compute_elevation/result"
        },
        "cvi_geojson": {
          "type": "File",
          "label": "CVI results",
          "doc": "Final Coastal Vulnerability Index values for all transects",
          "outputSource": "compute_cvi/out_geojson"
        }
      },
      "steps": {
        "node_eodag_download_config": {
          "label": "Download configuration [EODAG]",
          "doc": "Download the configuration JSON file from STAC item",
          "run": "#eodag_search",
          "in": {
            "stac_item_url": "config_stac_item_url"
          },
          "out": [
            "data_output_dir"
          ]
        },
        "node_eodag_download_aois": {
          "label": "Download AOIs [EODAG]",
          "doc": "Download the Mediterranean AOIs CSV from STAC item",
          "run": "#eodag_search",
          "in": {
            "stac_item_url": "aois_stac_item_url"
          },
          "out": [
            "data_output_dir"
          ]
        },
        "node_eodag_download_tokens": {
          "label": "Download tokens [EODAG]",
          "doc": "Download the authentication tokens file from STAC item",
          "run": "#eodag_search",
          "in": {
            "stac_item_url": "tokens_stac_item_url"
          },
          "out": [
            "data_output_dir"
          ]
        },
        "setup_env": {
          "label": "Setup Environment",
          "run": "#setup-env-tool",
          "in": {
            "config_json": {
              "source": "node_eodag_download_config/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.json$/i); })[0])"
            },
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "config_validated"
          ]
        },
        "extract_coastline": {
          "label": "Extract Coastline",
          "run": "#extract-coastline-tool",
          "in": {
            "med_aois_csv": {
              "source": "node_eodag_download_aois/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.csv$/i); })[0])"
            },
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "coastline_gpkg"
          ]
        },
        "generate_transects": {
          "label": "Generate Transects",
          "run": "#generate-transects-tool",
          "in": {
            "coastline_gpkg": "extract_coastline/coastline_gpkg",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "transects_geojson"
          ]
        },
        "compute_landcover": {
          "label": "Compute Landcover",
          "run": "#compute-parameter-tool",
          "in": {
            "script": {
              "default": "/app/steps/compute_landcover.py"
            },
            "transects_geojson": "generate_transects/transects_geojson",
            "tokens_env": {
              "source": "node_eodag_download_tokens/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"
            },
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "result"
          ]
        },
        "compute_slope": {
          "label": "Compute Slope",
          "run": "#compute-parameter-tool",
          "in": {
            "script": {
              "default": "/app/steps/compute_slope.py"
            },
            "transects_geojson": "generate_transects/transects_geojson",
            "tokens_env": {
              "source": "node_eodag_download_tokens/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"
            },
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "result"
          ]
        },
        "compute_erosion": {
          "label": "Compute Erosion",
          "run": "#compute-parameter-tool",
          "in": {
            "script": {
              "default": "/app/steps/compute_erosion.py"
            },
            "transects_geojson": "generate_transects/transects_geojson",
            "tokens_env": {
              "source": "node_eodag_download_tokens/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"
            },
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "result"
          ]
        },
        "compute_elevation": {
          "label": "Compute Elevation",
          "run": "#compute-parameter-tool",
          "in": {
            "script": {
              "default": "/app/steps/compute_elevation.py"
            },
            "transects_geojson": "generate_transects/transects_geojson",
            "tokens_env": {
              "source": "node_eodag_download_tokens/data_output_dir",
              "valueFrom": "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"
            },
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "result"
          ]
        },
        "compute_cvi": {
          "label": "Compute CVI Index",
          "run": "#compute-cvi-tool",
          "in": {
            "transects_landcover": "compute_landcover/result",
            "transects_slope": "compute_slope/result",
            "transects_erosion": "compute_erosion/result",
            "transects_elevation": "compute_elevation/result",
            "config_json": "setup_env/config_validated",
            "output_dir": {
              "default": "output_data"
            }
          },
          "out": [
            "out_geojson"
          ]
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "setup-env-tool",
      "label": "Setup Environment",
      "doc": "Validates configuration and initializes the working environment",
      "baseCommand": [
        "python3",
        "/app/steps/setup_env.py"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            "$(inputs.config_json)",
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "config_json": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Configuration JSON file"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 2
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "config_validated": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/config_validated.json"
          },
          "doc": "Validated configuration file"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "extract-coastline-tool",
      "label": "Extract Coastline",
      "doc": "Extracts coastline geometry from Mediterranean AOIs",
      "baseCommand": [
        "python3",
        "/app/steps/extract_coastline.py"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            "$(inputs.med_aois_csv)",
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "med_aois_csv": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Mediterranean areas of interest CSV"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 2
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "coastline_gpkg": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/coastline.gpkg"
          },
          "doc": "Extracted coastline GeoPackage"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "generate-transects-tool",
      "label": "Generate Transects",
      "doc": "Generates perpendicular transects along the coastline",
      "baseCommand": [
        "python3",
        "/app/steps/generate_transects.py"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            "$(inputs.coastline_gpkg)",
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "coastline_gpkg": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Coastline GeoPackage"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 2
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "transects_geojson": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/transects.geojson"
          },
          "doc": "Generated transects GeoJSON"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "compute-parameter-tool",
      "label": "Compute Parameter",
      "doc": "Computes a CVI parameter (landcover, slope, erosion, or elevation) for transects",
      "baseCommand": [
        "python3"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            {
              "entry": "$(inputs.transects_geojson)"
            },
            {
              "entry": "$(inputs.tokens_env)"
            },
            {
              "entry": "$(inputs.config_json)"
            },
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "script": {
          "type": "string",
          "inputBinding": {
            "position": 0
          },
          "doc": "Python script path for parameter computation"
        },
        "transects_geojson": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Transects GeoJSON file"
        },
        "tokens_env": {
          "type": "File",
          "inputBinding": {
            "position": 2
          },
          "doc": "Authentication tokens file"
        },
        "config_json": {
          "type": "File",
          "inputBinding": {
            "position": 3
          },
          "doc": "Configuration JSON file"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 4
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "result": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/*.geojson"
          },
          "doc": "Transects enriched with parameter data"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "compute-cvi-tool",
      "label": "Compute CVI",
      "doc": "Computes final Coastal Vulnerability Index from all parameters",
      "baseCommand": [
        "python3",
        "/app/steps/compute_cvi.py"
      ],
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/hartis-org/cvi-workflow:latest"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "InitialWorkDirRequirement": {
          "listing": [
            "$(inputs.transects_landcover)",
            "$(inputs.transects_slope)",
            "$(inputs.transects_erosion)",
            "$(inputs.transects_elevation)",
            "$(inputs.config_json)",
            {
              "entry": "$({class: 'Directory', listing: []})",
              "entryname": "$(inputs.output_dir)",
              "writable": true
            }
          ]
        }
      },
      "inputs": {
        "transects_landcover": {
          "type": "File",
          "inputBinding": {
            "position": 1
          },
          "doc": "Transects with landcover data"
        },
        "transects_slope": {
          "type": "File",
          "inputBinding": {
            "position": 2
          },
          "doc": "Transects with slope data"
        },
        "transects_erosion": {
          "type": "File",
          "inputBinding": {
            "position": 3
          },
          "doc": "Transects with erosion data"
        },
        "transects_elevation": {
          "type": "File",
          "inputBinding": {
            "position": 4
          },
          "doc": "Transects with elevation data"
        },
        "config_json": {
          "type": "File",
          "inputBinding": {
            "position": 5
          },
          "doc": "Configuration JSON file"
        },
        "output_dir": {
          "type": "string",
          "inputBinding": {
            "position": 6
          },
          "doc": "Output directory path"
        }
      },
      "outputs": {
        "out_geojson": {
          "type": "File",
          "outputBinding": {
            "glob": "$(inputs.output_dir)/transects_with_cvi_equal.geojson"
          },
          "doc": "Final CVI results GeoJSON"
        }
      }
    },
    {
      "class": "CommandLineTool",
      "id": "eodag_search",
      "label": "Download input data",
      "doc": "Downloads STAC item assets using EODAG",
      "s:softwareVersion": "latest",
      "hints": {
        "DockerRequirement": {
          "dockerPull": "ghcr.io/cs-si/eodag:v3.10.x"
        }
      },
      "requirements": {
        "InlineJavascriptRequirement": {},
        "NetworkAccess": {
          "networkAccess": true
        }
      },
      "baseCommand": [
        "eodag",
        "download"
      ],
      "arguments": [
        {
          "prefix": "--output-dir",
          "valueFrom": "$(runtime.outdir)"
        }
      ],
      "inputs": {
        "stac_item_url": {
          "type": "string",
          "inputBinding": {
            "prefix": "--stac-item"
          },
          "doc": "URL of the STAC item to download"
        }
      },
      "outputs": {
        "data_output_dir": {
          "type": "Directory",
          "outputBinding": {
            "glob": "$(runtime.outdir)/*"
          },
          "doc": "Directory containing downloaded STAC item assets"
        }
      }
    }
  ]
}
```

#### ttl
```ttl
@prefix cwl: <https://w3id.org/cwl/cwl#> .
@prefix dct: <http://purl.org/dc/terms/> .
@prefix ns1: <rdf:> .
@prefix ns2: <s:> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

[] cwl:cwlVersion <file:///github/workspace/v1.2> ;
    cwl:graph [ rdfs:label "Compute CVI"^^xsd:string ;
            dct:identifier <file:///github/workspace/compute-cvi-tool> ;
            rdfs:comment "Computes final Coastal Vulnerability Index from all parameters"^^xsd:string ;
            cwl:baseCommand "[\"python3\",\"/app/steps/compute_cvi.py\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "ghcr.io/hartis-org/cvi-workflow:latest"^^xsd:string ] ] ;
            cwl:input ( [ cwl:config_json [ rdfs:comment "Configuration JSON file"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "5"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:output_dir [ rdfs:comment "Output directory path"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "6"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:transects_elevation [ rdfs:comment "Transects with elevation data"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "4"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:transects_erosion [ rdfs:comment "Transects with erosion data"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "3"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:transects_landcover [ rdfs:comment "Transects with landcover data"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "1"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:transects_slope [ rdfs:comment "Transects with slope data"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "2"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:output ( [ cwl:out_geojson [ rdfs:comment "Final CVI results GeoJSON"^^xsd:string ;
                                cwl:outputBinding [ cwl:glob "$(inputs.output_dir)/transects_with_cvi_equal.geojson"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:requirements [ cwl:InitialWorkDirRequirement [ cwl:listing [ cwl:entry "$({class: 'Directory', listing: []})" ;
                                    cwl:entryname "$(inputs.output_dir)" ;
                                    cwl:writable true ],
                                "$(inputs.config_json)",
                                "$(inputs.transects_elevation)",
                                "$(inputs.transects_erosion)",
                                "$(inputs.transects_landcover)",
                                "$(inputs.transects_slope)" ] ;
                    cwl:InlineJavascriptRequirement [ ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ rdfs:label "Extract Coastline"^^xsd:string ;
            dct:identifier <file:///github/workspace/extract-coastline-tool> ;
            rdfs:comment "Extracts coastline geometry from Mediterranean AOIs"^^xsd:string ;
            cwl:baseCommand "[\"python3\",\"/app/steps/extract_coastline.py\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "ghcr.io/hartis-org/cvi-workflow:latest"^^xsd:string ] ] ;
            cwl:input ( [ cwl:med_aois_csv [ rdfs:comment "Mediterranean areas of interest CSV"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "1"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:output_dir [ rdfs:comment "Output directory path"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "2"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/string> ] ] ) ;
            cwl:output ( [ cwl:coastline_gpkg [ rdfs:comment "Extracted coastline GeoPackage"^^xsd:string ;
                                cwl:outputBinding [ cwl:glob "$(inputs.output_dir)/coastline.gpkg"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:requirements [ cwl:InitialWorkDirRequirement [ cwl:listing [ cwl:entry "$({class: 'Directory', listing: []})" ;
                                    cwl:entryname "$(inputs.output_dir)" ;
                                    cwl:writable true ],
                                "$(inputs.med_aois_csv)" ] ;
                    cwl:InlineJavascriptRequirement [ ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ rdfs:label "Download input data"^^xsd:string ;
            dct:identifier <file:///github/workspace/eodag_search> ;
            rdfs:comment "Downloads STAC item assets using EODAG"^^xsd:string ;
            cwl:arguments ( [ cwl:prefix "--output-dir"^^xsd:string ;
                        cwl:valueFrom "$(runtime.outdir)"^^xsd:string ] ) ;
            cwl:baseCommand "[\"eodag\",\"download\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "ghcr.io/cs-si/eodag:v3.10.x"^^xsd:string ] ] ;
            cwl:input ( [ cwl:stac_item_url [ rdfs:comment "URL of the STAC item to download"^^xsd:string ;
                                cwl:inputBinding [ cwl:prefix "--stac-item"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/string> ] ] ) ;
            cwl:output ( [ cwl:data_output_dir [ rdfs:comment "Directory containing downloaded STAC item assets"^^xsd:string ;
                                cwl:outputBinding [ cwl:glob "$(runtime.outdir)/*"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/Directory> ] ] ) ;
            cwl:requirements [ cwl:InlineJavascriptRequirement [ ] ;
                    cwl:NetworkAccess [ cwl:networkAccess true ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ;
            ns2:softwareVersion "latest" ],
        [ rdfs:label "Compute Parameter"^^xsd:string ;
            dct:identifier <file:///github/workspace/compute-parameter-tool> ;
            rdfs:comment "Computes a CVI parameter (landcover, slope, erosion, or elevation) for transects"^^xsd:string ;
            cwl:baseCommand "[\"python3\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "ghcr.io/hartis-org/cvi-workflow:latest"^^xsd:string ] ] ;
            cwl:input ( [ cwl:config_json [ rdfs:comment "Configuration JSON file"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "3"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:output_dir [ rdfs:comment "Output directory path"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "4"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:script [ rdfs:comment "Python script path for parameter computation"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "0"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:tokens_env [ rdfs:comment "Authentication tokens file"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "2"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:transects_geojson [ rdfs:comment "Transects GeoJSON file"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "1"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:output ( [ cwl:result [ rdfs:comment "Transects enriched with parameter data"^^xsd:string ;
                                cwl:outputBinding [ cwl:glob "$(inputs.output_dir)/*.geojson"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:requirements [ cwl:InitialWorkDirRequirement [ cwl:listing [ cwl:entry "$(inputs.tokens_env)" ],
                                [ cwl:entry "$(inputs.transects_geojson)" ],
                                [ cwl:entry "$({class: 'Directory', listing: []})" ;
                                    cwl:entryname "$(inputs.output_dir)" ;
                                    cwl:writable true ],
                                [ cwl:entry "$(inputs.config_json)" ] ] ;
                    cwl:InlineJavascriptRequirement [ ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ rdfs:label "CVI Workflow (Dockerized)"^^xsd:string ;
            dct:identifier <file:///github/workspace/cvi-workflow> ;
            rdfs:comment """This workflow computes the Coastal Vulnerability Index (CVI) for Mediterranean coastal areas.
It processes coastline data, generates transects, computes various coastal parameters
(landcover, slope, erosion, elevation), and calculates the final CVI values.
"""^^xsd:string ;
            cwl:input ( [ cwl:aois_stac_item_url [ rdfs:label "AOIs STAC item URL"^^xsd:string ;
                                rdfs:comment "URL of the STAC item containing the Mediterranean AOIs CSV file"^^xsd:string ;
                                cwl:default "\"https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/mediterranean-coastal-aois\""^^rdf:JSON ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:config_stac_item_url [ rdfs:label "Configuration STAC item URL"^^xsd:string ;
                                rdfs:comment "URL of the STAC item containing the configuration JSON file"^^xsd:string ;
                                cwl:default "\"https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/cvi-scoring-configuration\""^^rdf:JSON ;
                                cwl:type <file:///github/workspace/string> ] ;
                        cwl:tokens_stac_item_url [ rdfs:label "Tokens STAC item URL"^^xsd:string ;
                                rdfs:comment "URL of the STAC item containing the authentication tokens file"^^xsd:string ;
                                cwl:default "\"https://eocatalog.p2.csgroup.space/collections/cvi-workflow-resources/items/cvi-authentication-template\""^^rdf:JSON ;
                                cwl:type <file:///github/workspace/string> ] ] ) ;
            cwl:output ( [ cwl:coastline_gpkg [ rdfs:label "Coastline GeoPackage"^^xsd:string ;
                                rdfs:comment "Extracted coastline geometry in GeoPackage format"^^xsd:string ;
                                cwl:outputSource <file:///github/workspace/extract_coastline/coastline_gpkg> ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:cvi_geojson [ rdfs:label "CVI results"^^xsd:string ;
                                rdfs:comment "Final Coastal Vulnerability Index values for all transects"^^xsd:string ;
                                cwl:outputSource <file:///github/workspace/compute_cvi/out_geojson> ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:transects_elevation [ rdfs:label "Transects with elevation data"^^xsd:string ;
                                rdfs:comment "Transects enriched with elevation information"^^xsd:string ;
                                cwl:outputSource <file:///github/workspace/compute_elevation/result> ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:transects_erosion [ rdfs:label "Transects with erosion data"^^xsd:string ;
                                rdfs:comment "Transects enriched with erosion information"^^xsd:string ;
                                cwl:outputSource <file:///github/workspace/compute_erosion/result> ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:transects_geojson [ rdfs:label "Generated transects"^^xsd:string ;
                                rdfs:comment "Perpendicular transects generated along the coastline"^^xsd:string ;
                                cwl:outputSource <file:///github/workspace/generate_transects/transects_geojson> ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:transects_landcover [ rdfs:label "Transects with landcover data"^^xsd:string ;
                                rdfs:comment "Transects enriched with landcover information"^^xsd:string ;
                                cwl:outputSource <file:///github/workspace/compute_landcover/result> ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:transects_slope [ rdfs:label "Transects with slope data"^^xsd:string ;
                                rdfs:comment "Transects enriched with slope information"^^xsd:string ;
                                cwl:outputSource <file:///github/workspace/compute_slope/result> ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:validated_config [ rdfs:label "Validated configuration"^^xsd:string ;
                                rdfs:comment "Validated configuration JSON file"^^xsd:string ;
                                cwl:outputSource <file:///github/workspace/setup_env/config_validated> ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:requirements [ cwl:InlineJavascriptRequirement [ ] ;
                    cwl:StepInputExpressionRequirement [ ] ] ;
            cwl:steps [ cwl:compute_cvi [ rdfs:label "Compute CVI Index"^^xsd:string ;
                            cwl:in [ cwl:config_json "setup_env/config_validated" ;
                                    cwl:output_dir [ cwl:default "\"output_data\""^^rdf:JSON ] ;
                                    cwl:transects_elevation "compute_elevation/result" ;
                                    cwl:transects_erosion "compute_erosion/result" ;
                                    cwl:transects_landcover "compute_landcover/result" ;
                                    cwl:transects_slope "compute_slope/result" ] ;
                            cwl:out ( "out_geojson" ) ;
                            cwl:run <file:///github/workspace/#compute-cvi-tool> ] ;
                    cwl:compute_elevation [ rdfs:label "Compute Elevation"^^xsd:string ;
                            cwl:in [ cwl:config_json "setup_env/config_validated" ;
                                    cwl:output_dir [ cwl:default "\"output_data\""^^rdf:JSON ] ;
                                    cwl:script [ cwl:default "\"/app/steps/compute_elevation.py\""^^rdf:JSON ] ;
                                    cwl:tokens_env [ cwl:source <file:///github/workspace/node_eodag_download_tokens/data_output_dir> ;
                                            cwl:valueFrom "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"^^xsd:string ] ;
                                    cwl:transects_geojson "generate_transects/transects_geojson" ] ;
                            cwl:out ( "result" ) ;
                            cwl:run <file:///github/workspace/#compute-parameter-tool> ] ;
                    cwl:compute_erosion [ rdfs:label "Compute Erosion"^^xsd:string ;
                            cwl:in [ cwl:config_json "setup_env/config_validated" ;
                                    cwl:output_dir [ cwl:default "\"output_data\""^^rdf:JSON ] ;
                                    cwl:script [ cwl:default "\"/app/steps/compute_erosion.py\""^^rdf:JSON ] ;
                                    cwl:tokens_env [ cwl:source <file:///github/workspace/node_eodag_download_tokens/data_output_dir> ;
                                            cwl:valueFrom "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"^^xsd:string ] ;
                                    cwl:transects_geojson "generate_transects/transects_geojson" ] ;
                            cwl:out ( "result" ) ;
                            cwl:run <file:///github/workspace/#compute-parameter-tool> ] ;
                    cwl:compute_landcover [ rdfs:label "Compute Landcover"^^xsd:string ;
                            cwl:in [ cwl:config_json "setup_env/config_validated" ;
                                    cwl:output_dir [ cwl:default "\"output_data\""^^rdf:JSON ] ;
                                    cwl:script [ cwl:default "\"/app/steps/compute_landcover.py\""^^rdf:JSON ] ;
                                    cwl:tokens_env [ cwl:source <file:///github/workspace/node_eodag_download_tokens/data_output_dir> ;
                                            cwl:valueFrom "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"^^xsd:string ] ;
                                    cwl:transects_geojson "generate_transects/transects_geojson" ] ;
                            cwl:out ( "result" ) ;
                            cwl:run <file:///github/workspace/#compute-parameter-tool> ] ;
                    cwl:compute_slope [ rdfs:label "Compute Slope"^^xsd:string ;
                            cwl:in [ cwl:config_json "setup_env/config_validated" ;
                                    cwl:output_dir [ cwl:default "\"output_data\""^^rdf:JSON ] ;
                                    cwl:script [ cwl:default "\"/app/steps/compute_slope.py\""^^rdf:JSON ] ;
                                    cwl:tokens_env [ cwl:source <file:///github/workspace/node_eodag_download_tokens/data_output_dir> ;
                                            cwl:valueFrom "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.env$/i); })[0])"^^xsd:string ] ;
                                    cwl:transects_geojson "generate_transects/transects_geojson" ] ;
                            cwl:out ( "result" ) ;
                            cwl:run <file:///github/workspace/#compute-parameter-tool> ] ;
                    cwl:extract_coastline [ rdfs:label "Extract Coastline"^^xsd:string ;
                            cwl:in [ cwl:med_aois_csv [ cwl:source <file:///github/workspace/node_eodag_download_aois/data_output_dir> ;
                                            cwl:valueFrom "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.csv$/i); })[0])"^^xsd:string ] ;
                                    cwl:output_dir [ cwl:default "\"output_data\""^^rdf:JSON ] ] ;
                            cwl:out ( "coastline_gpkg" ) ;
                            cwl:run <file:///github/workspace/#extract-coastline-tool> ] ;
                    cwl:generate_transects [ rdfs:label "Generate Transects"^^xsd:string ;
                            cwl:in [ cwl:coastline_gpkg "extract_coastline/coastline_gpkg" ;
                                    cwl:output_dir [ cwl:default "\"output_data\""^^rdf:JSON ] ] ;
                            cwl:out ( "transects_geojson" ) ;
                            cwl:run <file:///github/workspace/#generate-transects-tool> ] ;
                    cwl:node_eodag_download_aois [ rdfs:label "Download AOIs [EODAG]"^^xsd:string ;
                            rdfs:comment "Download the Mediterranean AOIs CSV from STAC item"^^xsd:string ;
                            cwl:in [ cwl:stac_item_url "aois_stac_item_url" ] ;
                            cwl:out ( "data_output_dir" ) ;
                            cwl:run <file:///github/workspace/#eodag_search> ] ;
                    cwl:node_eodag_download_config [ rdfs:label "Download configuration [EODAG]"^^xsd:string ;
                            rdfs:comment "Download the configuration JSON file from STAC item"^^xsd:string ;
                            cwl:in [ cwl:stac_item_url "config_stac_item_url" ] ;
                            cwl:out ( "data_output_dir" ) ;
                            cwl:run <file:///github/workspace/#eodag_search> ] ;
                    cwl:node_eodag_download_tokens [ rdfs:label "Download tokens [EODAG]"^^xsd:string ;
                            rdfs:comment "Download the authentication tokens file from STAC item"^^xsd:string ;
                            cwl:in [ cwl:stac_item_url "tokens_stac_item_url" ] ;
                            cwl:out ( "data_output_dir" ) ;
                            cwl:run <file:///github/workspace/#eodag_search> ] ;
                    cwl:setup_env [ rdfs:label "Setup Environment"^^xsd:string ;
                            cwl:in [ cwl:config_json [ cwl:source <file:///github/workspace/node_eodag_download_config/data_output_dir> ;
                                            cwl:valueFrom "$(self.listing.filter(function(f) { return f.basename.match(/.*\\.json$/i); })[0])"^^xsd:string ] ;
                                    cwl:output_dir [ cwl:default "\"output_data\""^^rdf:JSON ] ] ;
                            cwl:out ( "config_validated" ) ;
                            cwl:run <file:///github/workspace/#setup-env-tool> ] ] ;
            ns1:type <file:///github/workspace/Workflow> ;
            ns2:author [ ns1:type ns2:Person ;
                    ns2:name "HARTIS Organization" ;
                    ns2:url "https://github.com/hartis-org" ] ;
            ns2:codeRepository "https://github.com/hartis-org/cvi-workflow" ;
            ns2:dateCreated "2024-01-01" ;
            ns2:keywords "CVI, coastal vulnerability, Mediterranean, earth observation" ;
            ns2:license "https://opensource.org/licenses/MIT" ;
            ns2:version "1.0.0" ],
        [ rdfs:label "Generate Transects"^^xsd:string ;
            dct:identifier <file:///github/workspace/generate-transects-tool> ;
            rdfs:comment "Generates perpendicular transects along the coastline"^^xsd:string ;
            cwl:baseCommand "[\"python3\",\"/app/steps/generate_transects.py\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "ghcr.io/hartis-org/cvi-workflow:latest"^^xsd:string ] ] ;
            cwl:input ( [ cwl:coastline_gpkg [ rdfs:comment "Coastline GeoPackage"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "1"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:output_dir [ rdfs:comment "Output directory path"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "2"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/string> ] ] ) ;
            cwl:output ( [ cwl:transects_geojson [ rdfs:comment "Generated transects GeoJSON"^^xsd:string ;
                                cwl:outputBinding [ cwl:glob "$(inputs.output_dir)/transects.geojson"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:requirements [ cwl:InitialWorkDirRequirement [ cwl:listing [ cwl:entry "$({class: 'Directory', listing: []})" ;
                                    cwl:entryname "$(inputs.output_dir)" ;
                                    cwl:writable true ],
                                "$(inputs.coastline_gpkg)" ] ;
                    cwl:InlineJavascriptRequirement [ ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ],
        [ rdfs:label "Setup Environment"^^xsd:string ;
            dct:identifier <file:///github/workspace/setup-env-tool> ;
            rdfs:comment "Validates configuration and initializes the working environment"^^xsd:string ;
            cwl:baseCommand "[\"python3\",\"/app/steps/setup_env.py\"]"^^rdf:JSON ;
            cwl:hints [ cwl:DockerRequirement [ cwl:dockerPull "ghcr.io/hartis-org/cvi-workflow:latest"^^xsd:string ] ] ;
            cwl:input ( [ cwl:config_json [ rdfs:comment "Configuration JSON file"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "1"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/File> ] ;
                        cwl:output_dir [ rdfs:comment "Output directory path"^^xsd:string ;
                                cwl:inputBinding [ cwl:position "2"^^xsd:int ] ;
                                cwl:type <file:///github/workspace/string> ] ] ) ;
            cwl:output ( [ cwl:config_validated [ rdfs:comment "Validated configuration file"^^xsd:string ;
                                cwl:outputBinding [ cwl:glob "$(inputs.output_dir)/config_validated.json"^^xsd:string ] ;
                                cwl:type <file:///github/workspace/File> ] ] ) ;
            cwl:requirements [ cwl:InitialWorkDirRequirement [ cwl:listing [ cwl:entry "$({class: 'Directory', listing: []})" ;
                                    cwl:entryname "$(inputs.output_dir)" ;
                                    cwl:writable true ],
                                "$(inputs.config_json)" ] ;
                    cwl:InlineJavascriptRequirement [ ] ] ;
            ns1:type <file:///github/workspace/CommandLineTool> ] ;
    cwl:namespaces "{\"s\":\"https://schema.org/\"}"^^rdf:JSON ;
    cwl:schemas ( "http://schema.org/version/latest/schemaorg-current-http.rdf" ) .


```

## Schema

```yaml
$ref: https://raw.githubusercontent.com/common-workflow-language/cwl-v1.2/main/json-schema/cwl.yaml
x-jsonld-extra-terms:
  '@comment': Metadata and provenance
  cwlVersion:
    x-jsonld-id: https://w3id.org/cwl/cwl#cwlVersion
    x-jsonld-type: '@id'
  class:
    x-jsonld-id: rdf:type
    x-jsonld-type: '@id'
  $graph:
    x-jsonld-id: https://w3id.org/cwl/cwl#graph
    x-jsonld-container: '@graph'
  id:
    x-jsonld-id: http://purl.org/dc/terms/identifier
    x-jsonld-type: '@id'
  label:
    x-jsonld-id: http://www.w3.org/2000/01/rdf-schema#label
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  doc:
    x-jsonld-id: http://www.w3.org/2000/01/rdf-schema#comment
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  inputs:
    x-jsonld-id: https://w3id.org/cwl/cwl#input
    x-jsonld-container: '@list'
  outputs:
    x-jsonld-id: https://w3id.org/cwl/cwl#output
    x-jsonld-container: '@list'
  steps:
    x-jsonld-id: https://w3id.org/cwl/cwl#steps
    x-jsonld-type: '@id'
  requirements:
    x-jsonld-id: https://w3id.org/cwl/cwl#requirements
    x-jsonld-container: '@set'
  hints:
    x-jsonld-id: https://w3id.org/cwl/cwl#hints
    x-jsonld-container: '@set'
  type:
    x-jsonld-id: https://w3id.org/cwl/cwl#type
    x-jsonld-type: '@id'
  format:
    x-jsonld-id: https://w3id.org/cwl/cwl#format
    x-jsonld-type: '@id'
  default:
    x-jsonld-id: https://w3id.org/cwl/cwl#default
    x-jsonld-type: '@json'
  baseCommand:
    x-jsonld-id: https://w3id.org/cwl/cwl#baseCommand
    x-jsonld-type: '@json'
  arguments:
    x-jsonld-id: https://w3id.org/cwl/cwl#arguments
    x-jsonld-container: '@list'
  stdin:
    x-jsonld-id: https://w3id.org/cwl/cwl#stdin
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  stdout:
    x-jsonld-id: https://w3id.org/cwl/cwl#stdout
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  stderr:
    x-jsonld-id: https://w3id.org/cwl/cwl#stderr
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  run:
    x-jsonld-id: https://w3id.org/cwl/cwl#run
    x-jsonld-type: '@id'
  in:
    x-jsonld-id: https://w3id.org/cwl/cwl#in
    x-jsonld-type: '@id'
  out:
    x-jsonld-id: https://w3id.org/cwl/cwl#out
    x-jsonld-container: '@list'
  outputSource:
    x-jsonld-id: https://w3id.org/cwl/cwl#outputSource
    x-jsonld-type: '@id'
  source:
    x-jsonld-id: https://w3id.org/cwl/cwl#source
    x-jsonld-type: '@id'
  CommandLineTool: https://w3id.org/cwl/cwl#CommandLineTool
  Workflow: https://w3id.org/cwl/cwl#Workflow
  ExpressionTool: https://w3id.org/cwl/cwl#ExpressionTool
  'null': https://w3id.org/cwl/cwl#null
  boolean: http://www.w3.org/2001/XMLSchema#boolean
  int: http://www.w3.org/2001/XMLSchema#int
  long: http://www.w3.org/2001/XMLSchema#long
  float: http://www.w3.org/2001/XMLSchema#float
  double: http://www.w3.org/2001/XMLSchema#double
  string: http://www.w3.org/2001/XMLSchema#string
  File: https://w3id.org/cwl/cwl#File
  Directory: https://w3id.org/cwl/cwl#Directory
  array: https://w3id.org/cwl/cwl#array
  record: https://w3id.org/cwl/cwl#record
  enum: https://w3id.org/cwl/cwl#enum
  items:
    x-jsonld-id: https://w3id.org/cwl/cwl#items
    x-jsonld-type: '@id'
  fields:
    x-jsonld-id: https://w3id.org/cwl/cwl#fields
    x-jsonld-container: '@list'
  symbols:
    x-jsonld-id: https://w3id.org/cwl/cwl#symbols
    x-jsonld-container: '@list'
  path:
    x-jsonld-id: https://w3id.org/cwl/cwl#path
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  location:
    x-jsonld-id: https://w3id.org/cwl/cwl#location
    x-jsonld-type: '@id'
  basename:
    x-jsonld-id: https://schema.org/name
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  dirname:
    x-jsonld-id: https://w3id.org/cwl/cwl#dirname
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  nameroot:
    x-jsonld-id: https://w3id.org/cwl/cwl#nameroot
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  nameext:
    x-jsonld-id: https://w3id.org/cwl/cwl#nameext
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  checksum:
    x-jsonld-id: https://w3id.org/cwl/cwl#checksum
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  size:
    x-jsonld-id: https://schema.org/contentSize
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#long
  secondaryFiles:
    x-jsonld-id: https://w3id.org/cwl/cwl#secondaryFiles
    x-jsonld-container: '@list'
  InlineJavascriptRequirement: https://w3id.org/cwl/cwl#InlineJavascriptRequirement
  SchemaDefRequirement: https://w3id.org/cwl/cwl#SchemaDefRequirement
  DockerRequirement: https://w3id.org/cwl/cwl#DockerRequirement
  SoftwareRequirement: https://w3id.org/cwl/cwl#SoftwareRequirement
  InitialWorkDirRequirement: https://w3id.org/cwl/cwl#InitialWorkDirRequirement
  EnvVarRequirement: https://w3id.org/cwl/cwl#EnvVarRequirement
  ShellCommandRequirement: https://w3id.org/cwl/cwl#ShellCommandRequirement
  ResourceRequirement: https://w3id.org/cwl/cwl#ResourceRequirement
  WorkReuse: https://w3id.org/cwl/cwl#WorkReuse
  NetworkAccess: https://w3id.org/cwl/cwl#NetworkAccess
  InplaceUpdateRequirement: https://w3id.org/cwl/cwl#InplaceUpdateRequirement
  ToolTimeLimit: https://w3id.org/cwl/cwl#ToolTimeLimit
  SubworkflowFeatureRequirement: https://w3id.org/cwl/cwl#SubworkflowFeatureRequirement
  ScatterFeatureRequirement: https://w3id.org/cwl/cwl#ScatterFeatureRequirement
  MultipleInputFeatureRequirement: https://w3id.org/cwl/cwl#MultipleInputFeatureRequirement
  StepInputExpressionRequirement: https://w3id.org/cwl/cwl#StepInputExpressionRequirement
  dockerPull:
    x-jsonld-id: https://w3id.org/cwl/cwl#dockerPull
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  dockerLoad:
    x-jsonld-id: https://w3id.org/cwl/cwl#dockerLoad
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  dockerFile:
    x-jsonld-id: https://w3id.org/cwl/cwl#dockerFile
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  dockerImport:
    x-jsonld-id: https://w3id.org/cwl/cwl#dockerImport
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  dockerImageId:
    x-jsonld-id: https://w3id.org/cwl/cwl#dockerImageId
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  dockerOutputDirectory:
    x-jsonld-id: https://w3id.org/cwl/cwl#dockerOutputDirectory
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  inputBinding:
    x-jsonld-id: https://w3id.org/cwl/cwl#inputBinding
    x-jsonld-type: '@id'
  position:
    x-jsonld-id: https://w3id.org/cwl/cwl#position
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#int
  prefix:
    x-jsonld-id: https://w3id.org/cwl/cwl#prefix
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  separate:
    x-jsonld-id: https://w3id.org/cwl/cwl#separate
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#boolean
  itemSeparator:
    x-jsonld-id: https://w3id.org/cwl/cwl#itemSeparator
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  valueFrom:
    x-jsonld-id: https://w3id.org/cwl/cwl#valueFrom
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  shellQuote:
    x-jsonld-id: https://w3id.org/cwl/cwl#shellQuote
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#boolean
  loadContents:
    x-jsonld-id: https://w3id.org/cwl/cwl#loadContents
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#boolean
  loadListing:
    x-jsonld-id: https://w3id.org/cwl/cwl#loadListing
    x-jsonld-type: '@id'
  outputBinding:
    x-jsonld-id: https://w3id.org/cwl/cwl#outputBinding
    x-jsonld-type: '@id'
  glob:
    x-jsonld-id: https://w3id.org/cwl/cwl#glob
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  outputEval:
    x-jsonld-id: https://w3id.org/cwl/cwl#outputEval
    x-jsonld-type: http://www.w3.org/2001/XMLSchema#string
  scatter:
    x-jsonld-id: https://w3id.org/cwl/cwl#scatter
    x-jsonld-container: '@list'
  scatterMethod:
    x-jsonld-id: https://w3id.org/cwl/cwl#scatterMethod
    x-jsonld-type: '@id'
  intent:
    x-jsonld-id: http://www.w3.org/ns/prov#wasInfluencedBy
    x-jsonld-type: '@id'
  $namespaces:
    x-jsonld-id: https://w3id.org/cwl/cwl#namespaces
    x-jsonld-type: '@json'
  $schemas:
    x-jsonld-id: https://w3id.org/cwl/cwl#schemas
    x-jsonld-container: '@list'
  $import:
    x-jsonld-id: https://w3id.org/cwl/cwl#import
    x-jsonld-type: '@id'
  $include:
    x-jsonld-id: https://w3id.org/cwl/cwl#include
    x-jsonld-type: '@id'
x-jsonld-vocab: https://w3id.org/cwl/cwl#
x-jsonld-prefixes:
  cwl: https://w3id.org/cwl/cwl#
  dct: http://purl.org/dc/terms/
  rdfs: http://www.w3.org/2000/01/rdf-schema#
  xsd: http://www.w3.org/2001/XMLSchema#
  schema: https://schema.org/
  prov: http://www.w3.org/ns/prov#
  ogcproc: http://www.opengis.net/def/ogcapi/processes/

```

Links to the schema:

* YAML version: [schema.yaml](https://geolabs.github.io/bblocks-eoap-cct/build/annotated/cct/cwl-to-ogcprocess/schema.json)
* JSON version: [schema.json](https://geolabs.github.io/bblocks-eoap-cct/build/annotated/cct/cwl-to-ogcprocess/schema.yaml)


# JSON-LD Context

```jsonld
{
  "@context": {
    "@vocab": "https://w3id.org/cwl/cwl#",
    "@comment": "Metadata and provenance",
    "cwlVersion": {
      "@id": "cwl:cwlVersion",
      "@type": "@id"
    },
    "class": {
      "@id": "rdf:type",
      "@type": "@id"
    },
    "$graph": {
      "@id": "cwl:graph",
      "@container": "@graph"
    },
    "id": {
      "@id": "dct:identifier",
      "@type": "@id"
    },
    "label": {
      "@id": "rdfs:label",
      "@type": "xsd:string"
    },
    "doc": {
      "@id": "rdfs:comment",
      "@type": "xsd:string"
    },
    "inputs": {
      "@id": "cwl:input",
      "@container": "@list"
    },
    "outputs": {
      "@id": "cwl:output",
      "@container": "@list"
    },
    "steps": {
      "@id": "cwl:steps",
      "@type": "@id"
    },
    "requirements": {
      "@id": "cwl:requirements",
      "@container": "@set"
    },
    "hints": {
      "@id": "cwl:hints",
      "@container": "@set"
    },
    "type": {
      "@id": "cwl:type",
      "@type": "@id"
    },
    "format": {
      "@id": "cwl:format",
      "@type": "@id"
    },
    "default": {
      "@id": "cwl:default",
      "@type": "@json"
    },
    "baseCommand": {
      "@id": "cwl:baseCommand",
      "@type": "@json"
    },
    "arguments": {
      "@id": "cwl:arguments",
      "@container": "@list"
    },
    "stdin": {
      "@id": "cwl:stdin",
      "@type": "xsd:string"
    },
    "stdout": {
      "@id": "cwl:stdout",
      "@type": "xsd:string"
    },
    "stderr": {
      "@id": "cwl:stderr",
      "@type": "xsd:string"
    },
    "run": {
      "@id": "cwl:run",
      "@type": "@id"
    },
    "in": {
      "@id": "cwl:in",
      "@type": "@id"
    },
    "out": {
      "@id": "cwl:out",
      "@container": "@list"
    },
    "outputSource": {
      "@id": "cwl:outputSource",
      "@type": "@id"
    },
    "source": {
      "@id": "cwl:source",
      "@type": "@id"
    },
    "CommandLineTool": "cwl:CommandLineTool",
    "Workflow": "cwl:Workflow",
    "ExpressionTool": "cwl:ExpressionTool",
    "null": "cwl:null",
    "boolean": "xsd:boolean",
    "int": "xsd:int",
    "long": "xsd:long",
    "float": "xsd:float",
    "double": "xsd:double",
    "string": "xsd:string",
    "File": "cwl:File",
    "Directory": "cwl:Directory",
    "array": "cwl:array",
    "record": "cwl:record",
    "enum": "cwl:enum",
    "items": {
      "@id": "cwl:items",
      "@type": "@id"
    },
    "fields": {
      "@id": "cwl:fields",
      "@container": "@list"
    },
    "symbols": {
      "@id": "cwl:symbols",
      "@container": "@list"
    },
    "path": {
      "@id": "cwl:path",
      "@type": "xsd:string"
    },
    "location": {
      "@id": "cwl:location",
      "@type": "@id"
    },
    "basename": {
      "@id": "schema:name",
      "@type": "xsd:string"
    },
    "dirname": {
      "@id": "cwl:dirname",
      "@type": "xsd:string"
    },
    "nameroot": {
      "@id": "cwl:nameroot",
      "@type": "xsd:string"
    },
    "nameext": {
      "@id": "cwl:nameext",
      "@type": "xsd:string"
    },
    "checksum": {
      "@id": "cwl:checksum",
      "@type": "xsd:string"
    },
    "size": {
      "@id": "schema:contentSize",
      "@type": "xsd:long"
    },
    "secondaryFiles": {
      "@id": "cwl:secondaryFiles",
      "@container": "@list"
    },
    "InlineJavascriptRequirement": "cwl:InlineJavascriptRequirement",
    "SchemaDefRequirement": "cwl:SchemaDefRequirement",
    "DockerRequirement": "cwl:DockerRequirement",
    "SoftwareRequirement": "cwl:SoftwareRequirement",
    "InitialWorkDirRequirement": "cwl:InitialWorkDirRequirement",
    "EnvVarRequirement": "cwl:EnvVarRequirement",
    "ShellCommandRequirement": "cwl:ShellCommandRequirement",
    "ResourceRequirement": "cwl:ResourceRequirement",
    "WorkReuse": "cwl:WorkReuse",
    "NetworkAccess": "cwl:NetworkAccess",
    "InplaceUpdateRequirement": "cwl:InplaceUpdateRequirement",
    "ToolTimeLimit": "cwl:ToolTimeLimit",
    "SubworkflowFeatureRequirement": "cwl:SubworkflowFeatureRequirement",
    "ScatterFeatureRequirement": "cwl:ScatterFeatureRequirement",
    "MultipleInputFeatureRequirement": "cwl:MultipleInputFeatureRequirement",
    "StepInputExpressionRequirement": "cwl:StepInputExpressionRequirement",
    "dockerPull": {
      "@id": "cwl:dockerPull",
      "@type": "xsd:string"
    },
    "dockerLoad": {
      "@id": "cwl:dockerLoad",
      "@type": "xsd:string"
    },
    "dockerFile": {
      "@id": "cwl:dockerFile",
      "@type": "xsd:string"
    },
    "dockerImport": {
      "@id": "cwl:dockerImport",
      "@type": "xsd:string"
    },
    "dockerImageId": {
      "@id": "cwl:dockerImageId",
      "@type": "xsd:string"
    },
    "dockerOutputDirectory": {
      "@id": "cwl:dockerOutputDirectory",
      "@type": "xsd:string"
    },
    "inputBinding": {
      "@id": "cwl:inputBinding",
      "@type": "@id"
    },
    "position": {
      "@id": "cwl:position",
      "@type": "xsd:int"
    },
    "prefix": {
      "@id": "cwl:prefix",
      "@type": "xsd:string"
    },
    "separate": {
      "@id": "cwl:separate",
      "@type": "xsd:boolean"
    },
    "itemSeparator": {
      "@id": "cwl:itemSeparator",
      "@type": "xsd:string"
    },
    "valueFrom": {
      "@id": "cwl:valueFrom",
      "@type": "xsd:string"
    },
    "shellQuote": {
      "@id": "cwl:shellQuote",
      "@type": "xsd:boolean"
    },
    "loadContents": {
      "@id": "cwl:loadContents",
      "@type": "xsd:boolean"
    },
    "loadListing": {
      "@id": "cwl:loadListing",
      "@type": "@id"
    },
    "outputBinding": {
      "@id": "cwl:outputBinding",
      "@type": "@id"
    },
    "glob": {
      "@id": "cwl:glob",
      "@type": "xsd:string"
    },
    "outputEval": {
      "@id": "cwl:outputEval",
      "@type": "xsd:string"
    },
    "scatter": {
      "@id": "cwl:scatter",
      "@container": "@list"
    },
    "scatterMethod": {
      "@id": "cwl:scatterMethod",
      "@type": "@id"
    },
    "intent": {
      "@id": "prov:wasInfluencedBy",
      "@type": "@id"
    },
    "$namespaces": {
      "@id": "cwl:namespaces",
      "@type": "@json"
    },
    "$schemas": {
      "@id": "cwl:schemas",
      "@container": "@list"
    },
    "$import": {
      "@id": "cwl:import",
      "@type": "@id"
    },
    "$include": {
      "@id": "cwl:include",
      "@type": "@id"
    },
    "cwl": "https://w3id.org/cwl/cwl#",
    "dct": "http://purl.org/dc/terms/",
    "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
    "xsd": "http://www.w3.org/2001/XMLSchema#",
    "schema": "https://schema.org/",
    "prov": "http://www.w3.org/ns/prov#",
    "ogcproc": "http://www.opengis.net/def/ogcapi/processes/",
    "@version": 1.1
  }
}
```

You can find the full JSON-LD context here:
[context.jsonld](https://geolabs.github.io/bblocks-eoap-cct/build/annotated/cct/cwl-to-ogcprocess/context.jsonld)

## Sources

* [Common Workflow Language (CWL) Specification](https://www.commonwl.org/v1.2/)
* [OGC API - Processes Part 1: Core](https://docs.ogc.org/is/18-062r2/18-062r2.html)
* [OGC Best Practice for Earth Observation Application Package](https://docs.ogc.org/bp/20-089r1.html)
* [Earth Observation Application Package (EOAP) CWL Custom Types](https://github.com/eoap/schemas)

# For developers

The source code for this Building Block can be found in the following repository:

* URL: [https://github.com/GeoLabs/bblocks-eoap-cct](https://github.com/GeoLabs/bblocks-eoap-cct)
* Path: `_sources/cwl-to-ogcprocess`

