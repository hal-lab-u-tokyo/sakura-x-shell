#!/bin/sh

make -C ../ip_repo/aes128_rsm_hls genmask
# vitis_hls -f ../ip_repo/aes128_rsm_hls/create_ip.tcl target-board=sakura-x target-freq=20MHz

if command -v vitis-run >/dev/null 2>&1; then
	hls_wrapper=$(mktemp) || exit 1
	trap 'rm -f "$hls_wrapper"' EXIT
	printf '%s\n' 'set argc 2' 'set argv {target-board=sakura-x target-freq=20MHz}' \
		'source ../ip_repo/aes128_rsm_hls/create_ip.tcl' > "$hls_wrapper"
	vitis-run --mode hls --tcl "$hls_wrapper"
elif command -v vitis_hls >/dev/null 2>&1; then
	exec vitis_hls -f ../ip_repo/aes128_rsm_hls/create_ip.tcl target-board=sakura-x target-freq=20MHz
else
	echo "Neither vitis-run nor vitis_hls was found in PATH" >&2
	exit 1
fi