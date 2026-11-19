"""Regenerate values.schema.json from values.yaml defaults.

Usage: python3 hack/gen-values-schema.py charts/opencti/values.yaml charts/opencti/values.schema.json
Run it after adding or renaming a value. Needs PyYAML.
"""
import json, sys, yaml
vals = yaml.safe_load(open(sys.argv[1]))

# Paths left free-form: user-defined maps, raw Kubernetes snippets, subcharts.
OPEN = {
    "connectors", "opensearch", "rustfs", "redis",
    "global", "serviceAccount.annotations", "serviceMonitor.labels",
    "rabbitmq.nodeSelector", "rabbitmq.resources",
}
OPEN_LEAVES = {
    "annotations", "labels", "podAnnotations", "podLabels", "podSecurityContext",
    "securityContext", "nodeSelector", "affinity", "resources", "strategy",
}
SECRET_REF = {"type": "object", "additionalProperties": False,
              "properties": {"name": {"type": "string"}, "key": {"type": "string"}}}
S3_REF = {"type": "object", "additionalProperties": False,
          "properties": {"name": {"type": "string"}, "accessKeyKey": {"type": "string"},
                         "secretKeyKey": {"type": "string"}}}
INT_OR_STR = {"type": ["integer", "string"]}
EXTRA = {  # keys that are valid but commented out in values.yaml
    "server.podDisruptionBudget": {"minAvailable": INT_OR_STR},
    "worker.podDisruptionBudget": {"minAvailable": INT_OR_STR},
    "rabbitmq.persistence": {"storageClass": {"type": "string"}},
}
OVERRIDE = {
    "server.podDisruptionBudget.maxUnavailable": INT_OR_STR,
    "worker.podDisruptionBudget.maxUnavailable": INT_OR_STR,
    "externalRedis.mode": {"type": "string", "enum": ["single", "sentinel", "cluster"]},
    "externalS3.existingSecret": S3_REF,
}

def schema(v, path):
    if path in OVERRIDE:
        return OVERRIDE[path]
    leaf = path.split(".")[-1]
    if path.endswith("xistingSecret"):
        return SECRET_REF
    if isinstance(v, dict):
        if path in OPEN or leaf in OPEN_LEAVES:
            return {"type": "object"}
        props = {k: schema(x, f"{path}.{k}" if path else k) for k, x in v.items()}
        props.update(EXTRA.get(path, {}))
        return {"type": "object", "additionalProperties": False, "properties": props}
    if isinstance(v, bool):
        return {"type": "boolean"}
    if isinstance(v, int):
        return {"type": "integer"}
    if isinstance(v, float):
        return {"type": "number"}
    if isinstance(v, list):
        return {"type": "array"}
    return {"type": "string"}

out = schema(vals, "")
out = {"$schema": "http://json-schema.org/draft-07/schema#", "title": "opencti chart values", **out}
json.dump(out, open(sys.argv[2], "w"), indent=2)
open(sys.argv[2], "a").write("\n")
