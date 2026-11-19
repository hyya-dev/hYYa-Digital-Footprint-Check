#!/bin/zsh
# Records the App Store preview video (iPhone 6.9", 886x1920, 30 fps, H.264 ~11 Mbps, silent stereo AAC).
# The UI test StoreScreenshotsUITests/testPreviewVideo drives the app with sample data while
# `simctl io recordVideo` records, so a retake is a re-run. Usage: scripts/record-app-preview.sh <simulator-udid> <out.mp4>
# The trim points (START, CUT_FROM, CUT_TO, END, in seconds of the raw take) depend on the take: check a contact sheet
# (ffmpeg -i raw.mov -vf "fps=2,scale=150:-1,tile=12x6" -frames:v 1 sheet.png) and adjust them; keep the result 15–30 s.
set -e
UDID=$1; OUT=$2
START=${START:-8.0}; CUT_FROM=${CUT_FROM:-26.0}; CUT_TO=${CUT_TO:-28.5}; END=${END:-39.9}
TMP=$(mktemp -d)
xcodegen generate -q
xcodebuild build-for-testing -project hYYaFootprintInspector.xcodeproj -scheme "hYYa Footprint Inspector UITests" \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build/pv -quiet
xcrun simctl boot $UDID 2>/dev/null || true; xcrun simctl bootstatus $UDID -b >/dev/null
xcrun simctl status_bar $UDID override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
xcrun simctl io $UDID recordVideo --codec=h264 --force $TMP/raw.mov &
REC=$!; sleep 2
xcodebuild test-without-building -xctestrun build/pv/Build/Products/*.xctestrun -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:hYYaFootprintInspectorUITests/StoreScreenshotsUITests/testPreviewVideo -quiet
sleep 1; kill -INT $REC; wait $REC
ffmpeg -v error -y -i $TMP/raw.mov -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -filter_complex \
  "[0:v]trim=$START:$CUT_FROM,setpts=PTS-STARTPTS[a];[0:v]trim=$CUT_TO:$END,setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1[c];[c]fps=30,scale=886:-2:flags=lanczos,crop=886:1920:0:(ih-1920)/2,format=yuv420p[v]" \
  -map "[v]" -map 1:a -c:v libx264 -profile:v high -level:v 4.0 -b:v 11M -minrate 11M -maxrate 11M -bufsize 11M \
  -x264-params nal-hrd=cbr -c:a aac -b:a 256k -shortest -movflags +faststart "$OUT"
xcrun simctl status_bar $UDID clear; xcrun simctl shutdown $UDID
echo "Raw take kept in $TMP/raw.mov"; ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT"
