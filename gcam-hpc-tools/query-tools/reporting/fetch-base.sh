#!/usr/bin/env bash
# Assemble the pinned R/Java layers as OCI using standard Linux CLI tools.
set -Eeuo pipefail
[[ $# == 3 || $# == 4 ]] || {
    echo 'Usage: fetch-base.sh <pinned-docker-uri> <cache-dir> <oci-tar> [singularity-cache]' >&2
    exit 2
}
pin=sha256:4f6d7fffda537ec065fe5cf46510966c538532b40c5fa788cacccc97caeafc4c
image=$1
cache=$2
output=$3
singularity_cache=${4:-}
[[ "$image" == docker://*"@$pin" ]] || {
    echo "ERROR: slim preparation requires the Dockerfile's original pinned digest" >&2
    exit 1
}
for tool in curl jq sha256sum stat tar; do
    command -v "$tool" >/dev/null || { echo "ERROR: missing tool: $tool" >&2; exit 1; }
done
repository=${image#docker://}
repository=${repository%@*}
if [[ "$repository" != */* || "${repository%%/*}" != *.* ]]; then
    repository=registry-1.docker.io/$repository
fi
url=https://${repository%%/*}/v2/${repository#*/}
mkdir -p "$cache"
cache=$(cd "$cache" && pwd)
work=$(mktemp -d "$cache/oci-base.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'status=$?; echo "ERROR: verified base preparation failed (exit $status)" >&2; exit "$status"' ERR

digest_file() { sha256sum "$1" | awk '{print "sha256:" $1}'; }
valid_blob() {
    [[ -f "$1" && "$(stat -c %s "$1")" == "$2" && "$(digest_file "$1")" == "$3" ]]
}
curl_fetch() {
    local endpoint=$1 target=$2 resume=$3 accept=${4:-} attempt status=1
    local -a args
    for attempt in 1 2 3 4; do
        args=(--fail --silent --show-error --location --retry 0
              --connect-timeout 15 --max-time 1800 --output "$target")
        [[ -z "$accept" ]] || args+=(--header "Accept: $accept")
        if [[ "$resume" == 1 && -s "$target" ]]; then
            echo "Resuming layer at $(stat -c %s "$target") bytes" >&2
            args+=(--continue-at -)
        fi
        if curl "${args[@]}" "$endpoint"; then return 0; else status=$?; fi
        # Preserve partial downloads after timeouts. A server without range
        # support needs a full retry, which curl truncates on the next attempt.
        [[ "$status" != 33 ]] || resume=0
        [[ "$attempt" == 4 ]] || sleep 2
    done
    return "$status"
}
fetch_blob() {
    local digest=$1 size=$2 path="$cache/${1#sha256:}" candidate partial
    valid_blob "$path" "$size" "$digest" && return 0
    candidate="$singularity_cache/blob/blobs/sha256/${digest#sha256:}"
    if [[ -n "$singularity_cache" ]] && valid_blob "$candidate" "$size" "$digest"; then
        rm -f "$path"
        ln "$candidate" "$path" 2>/dev/null || cp "$candidate" "$path"
        return 0
    fi
    echo "Fetching verified layer: $digest ($size bytes)" >&2
    partial=$path.partial
    if ! valid_blob "$partial" "$size" "$digest"; then
        curl_fetch "$url/blobs/$digest" "$partial" 1
    fi
    valid_blob "$partial" "$size" "$digest" || {
        echo "ERROR: downloaded blob failed size/digest validation: $digest" >&2
        return 1
    }
    mv "$partial" "$path"
}

curl_fetch "$url/manifests/$pin" "$work/original.json" 0 \
    application/vnd.docker.distribution.manifest.v2+json
[[ "$(digest_file "$work/original.json")" == "$pin" ]] || {
    echo 'ERROR: base manifest digest differs from the Dockerfile' >&2; exit 1;
}
read -r config_digest config_size < <(jq -r '[.config.digest,.config.size] | @tsv' "$work/original.json")
fetch_blob "$config_digest" "$config_size"

# Require the exact history entries as well as digests before excluding data.
omit='{
 "sha256:53e25238677ff33867ece8f55fa5c0c45f9dbb4afc80f68d940ebc1818c561f3": "RUN /bin/sh -c git clone -b gcam-core https://github.com/bc3LC/gcamreport.git /root/gcamreport # buildkit",
 "sha256:3dbf92597f8c7d647df8be306d3c7487c73c10902080180e723267370b4a6f82": "COPY . /app # buildkit",
 "sha256:858ce090fe137b62379918aaafba6a5a7af1d795afcd98ffb877acacdebba31f": "RUN /bin/sh -c chown app:app -R /app # buildkit"
}'
jq -n --slurpfile manifest "$work/original.json" \
    --slurpfile config "$cache/${config_digest#sha256:}" --argjson omit "$omit" --arg pin "$pin" '
    $manifest[0] as $m | $config[0] as $c |
    [$c.history[] | select(.empty_layer != true)] as $history |
    if ($m.layers|length) != ($c.rootfs.diff_ids|length) or
       ($m.layers|length) != ($history|length) then error("Base history and layer counts differ") else . end |
    if $c.architecture != "amd64" or $c.os != "linux" then error("Base must be Linux amd64") else . end |
    [range(0; $m.layers|length) | select($omit[$m.layers[.].digest] != null)] as $removed |
    if ($removed|length) != ($omit|length) then error("Pinned data layers were not all found") else . end |
    if any($removed[]; $history[.].created_by != $omit[$m.layers[.].digest])
       then error("Unexpected contents in a layer selected for omission") else . end |
    [$m.layers|to_entries[] | .key as $i | select(($removed|index($i)) == null) | .value] as $layers |
    {layers: $layers,
     omitted_bytes: ([$removed[] | $m.layers[.].size] | add),
     config: ($c |
       .rootfs.diff_ids = [.rootfs.diff_ids|to_entries[] | .key as $i | select(($removed|index($i)) == null) | .value] |
       .history = (reduce .history[] as $row ({i:-1, rows:[]};
         if $row.empty_layer == true then .rows += [$row]
         else .i += 1 | .i as $i | if ($removed|index($i)) == null then .rows += [$row] else . end end) | .rows) |
       .config.Labels["org.gcamreport.base-manifest"] = $pin |
       .config.Labels["org.gcamreport.omitted-data-layers"] = ($omit|keys|join(",")))}
' > "$work/plan.json"
jq -r '"Verified base: \(.layers|length) layers, \(([.layers[].size]|add)/1000000) MB; omitted \(.omitted_bytes/1000000) MB of old application data."' "$work/plan.json"
jq -r '.layers[] | [.digest,.size] | @tsv' "$work/plan.json" > "$work/layers.tsv"

# At most three downloads at a time; wait for the whole batch on any failure.
pids=()
wait_batch() {
    local pid status=0
    for pid in "${pids[@]}"; do wait "$pid" || status=$?; done
    pids=()
    return "$status"
}
while IFS=$'\t' read -r digest size; do
    fetch_blob "$digest" "$size" &
    pids+=("$!")
    if [[ ${#pids[@]} == 3 ]]; then wait_batch; fi
done < "$work/layers.tsv"
wait_batch

mkdir -p "$work/blobs/sha256"
jq -c '.config' "$work/plan.json" > "$work/config.json"
new_config_digest=$(digest_file "$work/config.json")
new_config_size=$(stat -c %s "$work/config.json")
mv "$work/config.json" "$work/blobs/sha256/${new_config_digest#sha256:}"
jq -nc --slurpfile plan "$work/plan.json" --arg digest "$new_config_digest" --argjson size "$new_config_size" '
    {schemaVersion:2, mediaType:"application/vnd.oci.image.manifest.v1+json",
     config:{mediaType:"application/vnd.oci.image.config.v1+json",digest:$digest,size:$size},
     layers:[$plan[0].layers[] | .mediaType="application/vnd.oci.image.layer.v1.tar+gzip"]}
' > "$work/manifest.json"
new_manifest_digest=$(digest_file "$work/manifest.json")
new_manifest_size=$(stat -c %s "$work/manifest.json")
mv "$work/manifest.json" "$work/blobs/sha256/${new_manifest_digest#sha256:}"
jq -nc --arg digest "$new_manifest_digest" --argjson size "$new_manifest_size" '
    {schemaVersion:2,manifests:[{mediaType:"application/vnd.oci.image.manifest.v1+json",
      digest:$digest,size:$size,platform:{architecture:"amd64",os:"linux"}}]}
' > "$work/index.json"
echo '{"imageLayoutVersion":"1.0.0"}' > "$work/oci-layout"
while IFS=$'\t' read -r digest size; do
    path="$cache/${digest#sha256:}"
    ln "$path" "$work/blobs/sha256/${digest#sha256:}" 2>/dev/null || cp "$path" "$work/blobs/sha256/${digest#sha256:}"
done < "$work/layers.tsv"
# Explicit directories, USTAR and normalized ownership work with Singularity 3.11.
tar --format=ustar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 \
    -C "$work" -cf "$output" oci-layout index.json blobs
echo "Verified OCI archive ready: $output"
