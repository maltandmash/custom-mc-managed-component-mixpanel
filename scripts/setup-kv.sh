#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_PATH="$ROOT_DIR/wrangler.custom-mc.template.toml"
OUTPUT_PATH="$ROOT_DIR/wrangler.custom-mc.toml"
PLACEHOLDER="__KV_NAMESPACE_ID__"

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "Template not found at $TEMPLATE_PATH"
  exit 1
fi

component_name="$(sed -n 's/^name = "\(.*\)"/\1/p' "$TEMPLATE_PATH" | head -n 1)"
namespace_title="${component_name:-custom-mc-managed-component-mixpanel}-kv"
kv_id=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --id)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --id"
        exit 1
      fi
      kv_id="$2"
      shift 2
      ;;
    --name)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --name"
        exit 1
      fi
      namespace_title="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: bash scripts/setup-kv.sh [--id <namespace_id>] [--name <namespace_title>]"
      exit 1
      ;;
    *)
      namespace_title="$1"
      shift
      ;;
  esac
done

if [ -n "$kv_id" ] && ! [[ "$kv_id" =~ ^[a-f0-9]{32}$ ]]; then
  echo "Invalid KV namespace id format: $kv_id"
  exit 1
fi

cp "$TEMPLATE_PATH" "$OUTPUT_PATH"

if [ -z "$kv_id" ]; then
  if ! command -v npx >/dev/null 2>&1; then
    echo "npx is required to run Wrangler when --id is not provided."
    exit 1
  fi

  # Reuse existing namespace in the current account if one matches the title.
  set +e
  list_output="$(npx wrangler kv namespace list --format json 2>/dev/null)"
  list_status=$?
  if [ "$list_status" -ne 0 ]; then
    list_output="$(npx wrangler kv namespace list --json 2>/dev/null)"
    list_status=$?
  fi
  set -e

  if [ "$list_status" -eq 0 ] && [ -n "$list_output" ]; then
    kv_id="$(
      printf '%s' "$list_output" | node -e '
        let input = ""
        process.stdin.on("data", chunk => (input += chunk))
        process.stdin.on("end", () => {
          try {
            const parsed = JSON.parse(input)
            const namespaces = Array.isArray(parsed)
              ? parsed
              : Array.isArray(parsed.result)
                ? parsed.result
                : []
            const targetTitle = process.argv[1]
            const match = namespaces.find(ns => ns && ns.title === targetTitle)
            if (match && typeof match.id === "string") {
              process.stdout.write(match.id)
            }
          } catch {
            // Ignore parse errors and fall back to create.
          }
        })
      ' "$namespace_title"
    )"
  fi

  if [ -n "$kv_id" ]; then
    echo "Using existing KV namespace: $namespace_title ($kv_id)"
  else
    echo "Creating KV namespace: $namespace_title"
    set +e
    create_output="$(npx wrangler kv namespace create "$namespace_title" 2>&1)"
    create_status=$?
    set -e

    if [ "$create_status" -ne 0 ]; then
      echo "$create_output"
      exit "$create_status"
    fi

    kv_id="$(printf '%s\n' "$create_output" | sed -n 's/.*id = "\(.\{32\}\)".*/\1/p' | head -n 1)"

    if [ -z "$kv_id" ]; then
      kv_id="$(printf '%s\n' "$create_output" | sed -nE 's/.*"id"[[:space:]]*:[[:space:]]*"([a-f0-9]{32})".*/\1/p' | head -n 1)"
    fi

    if [ -z "$kv_id" ]; then
      echo "Could not parse KV namespace ID from Wrangler output."
      echo "$create_output"
      exit 1
    fi
  fi
fi

sed -i.bak "s/$PLACEHOLDER/$kv_id/g" "$OUTPUT_PATH"
rm -f "$OUTPUT_PATH.bak"

echo "KV namespace id set: $kv_id"
echo "Updated config: $OUTPUT_PATH"
