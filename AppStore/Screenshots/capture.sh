#!/bin/zsh
# Regenerates the App Store screenshots in this folder.
#
#   AppStore/Screenshots/capture.sh            iPhone 6.9", 6.5", iPad 13" and the Duo cover display
#   AppStore/Screenshots/capture.sh duo-cover  the Duo cover display only
#   AppStore/Screenshots/capture.sh duo-inner  the Duo inner display — open the phone
#                                              in Device Hub first (see README.md)
#
# Each shot is a Debug build launched with `-screenshot <scene>`, which stages
# the app over made-up history with the clock frozen (Shut/App/ScreenshotStage.swift).
# Nothing here touches a real install's data.
set -e
cd "${0:A:h}/../.."
here=AppStore/Screenshots
dd=${TMPDIR:-/tmp}/shut-screenshots
release=/Applications/Xcode.app/Contents/Developer
beta=/Applications/Xcode-beta.app/Contents/Developer

scenes=(running:1-timer home:2-home grace:3-grace kept:4-kept history:5-history settings:6-settings appearance:7-appearance)

# The editor is shown dressed in the Cute style, open on Colours: the most
# range in one image. Every other scene is Classic.
args_for() { # <scene>
  [[ $1 == appearance ]] && print -- -appearance.tab colours -theme blossom -face.style ring \
    -look.text rounded -look.numerals rounded -look.weight heavy -look.corners round
}

build() { # <developer dir> <derived data> [extra swift flags | TARGETED_DEVICE_FAMILY_OVERRIDE]
  local flags=$3 family=()
  if [[ $3 == TARGETED_DEVICE_FAMILY_OVERRIDE ]]; then flags=""; family=(TARGETED_DEVICE_FAMILY=1,2); fi
  DEVELOPER_DIR=$1 xcodebuild -project Shut.xcodeproj -scheme Shut -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath $2 \
    OTHER_SWIFT_FLAGS="\$(inherited) $flags" $family build -quiet
}

udid() { # <device name>
  xcrun simctl list devices available | grep -F "    $1 (" | head -1 | grep -oE '[0-9A-F-]{36}'
}

prepare() { # <udid> <app>
  # A fresh boot clears any permission alert a normal launch left queued.
  xcrun simctl shutdown $1 2>/dev/null || true
  xcrun simctl boot $1 2>/dev/null || true
  xcrun simctl bootstatus $1 -b >/dev/null
  xcrun simctl status_bar $1 override --time 9:41 --dataNetwork wifi --wifiMode active \
    --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 2>/dev/null || true
  xcrun simctl uninstall $1 com.zawmbi.shut 2>/dev/null || true
  xcrun simctl install $1 $2
}

# Launches a scene and captures it, retrying while everything below the status
# bar is one flat colour (the app hadn't drawn yet).
shoot() { # <udid> <out.png> <display or ""> <scene> [launch args…]
  local id=$1 out=$2 display=$3 scene=$4; shift 4
  for attempt in 1 2 3; do
    xcrun simctl terminate $id com.zawmbi.shut 2>/dev/null || true
    xcrun simctl launch $id com.zawmbi.shut -screenshot $scene -pro.cached YES "$@" >/dev/null
    sleep $((${WAIT:-4} + attempt * 2))
    xcrun simctl io $id screenshot --type=png ${display:+--display=$display} $out >/dev/null 2>&1
    python3 -c "import sys; from PIL import Image; i=Image.open(sys.argv[1]).convert('L'); w,h=i.size; lo,hi=i.crop((0,h//5,w,h*9//10)).getextrema(); sys.exit(0 if hi-lo > 24 else 1)" $out && return
  done
  echo "warning: $out still looks blank" >&2
}

iphone_set() { # <device name> <folder> <app>
  local id=$(udid "$1")
  [[ -n $id ]] || { echo "no simulator named $1" >&2; return 1; }
  prepare $id $3
  mkdir -p $here/$2
  for pair in $scenes; do shoot $id $here/$2/${pair#*:}.png "" ${pair%%:*} ${=$(args_for ${pair%%:*})}; done
}

# The Duo's two integrated displays, by device name — their UUIDs change on
# every boot. Only the one the app is on is lit.
cover=primary    # 1398×2034
inner=primary-1  # 2007×2853

if [[ $1 == duo-inner ]]; then
  export DEVELOPER_DIR=$beta
  id=$(udid "iPhone Duo")
  app=$dd/duo/Build/Products/Debug-iphonesimulator/Shut.app
  [[ -d $app ]] || build $beta $dd/duo "-D DUO_SDK"
  # No reinstall: the pose is set by hand and a reinstall would not move it,
  # but there's no reason to disturb the device either.
  mkdir -p $here/iPhone-Duo-inner
  for pair in $scenes; do
    [[ ${pair%%:*} == running ]] && continue   # the timer belongs to the cover display
    shoot $id $here/iPhone-Duo-inner/${pair#*:}.png $inner ${pair%%:*} ${=$(args_for ${pair%%:*})}
  done
  exit
fi

# Plain iPhone: the release Xcode, no DUO_SDK — the v1.0 binary's copy.
if [[ $1 != duo-cover ]]; then
export DEVELOPER_DIR=$release
build $release $dd/iphone
app=$dd/iphone/Build/Products/Debug-iphonesimulator/Shut.app
iphone_set "iPhone 18 Pro Max" iPhone-6.9in $app
iphone_set "iPhone 14 Plus (shots)" iPhone-6.5in $app

# iPad, 13". The project still ships iPhone-only (TARGETED_DEVICE_FAMILY = 1),
# so this build turns iPad on for itself. When iPad ships, flip the project
# setting and upload these.
build $release $dd/ipad TARGETED_DEVICE_FAMILY_OVERRIDE
iphone_set "iPad Pro 13-inch (M5)" iPad-13in $dd/ipad/Build/Products/Debug-iphonesimulator/Shut.app
fi

# Duo cover display: the simulator boots shut, so this needs no hands.
export DEVELOPER_DIR=$beta
build $beta $dd/duo "-D DUO_SDK"
app=$dd/duo/Build/Products/Debug-iphonesimulator/Shut.app
id=$(udid "iPhone Duo"); prepare $id $app
mkdir -p $here/iPhone-Duo-cover
# The face hides the home indicator, but only once it has faded.
export WAIT=10
shoot $id $here/iPhone-Duo-cover/1-ring-walnut.png $cover running
shoot $id $here/iPhone-Duo-cover/2-sunburst-atomic.png $cover running -face.style sunburst -theme atomic
shoot $id $here/iPhone-Duo-cover/3-digits-dusk.png $cover running -face.style digits -theme dusk -encouragement YES
shoot $id $here/iPhone-Duo-cover/4-dots-cute.png $cover running -face.style dots -theme blossom \
  -look.text rounded -look.numerals rounded -look.weight heavy -look.corners round
shoot $id $here/iPhone-Duo-cover/5-hairline-chic.png $cover running -face.style hairline -theme noir \
  -look.text serif -look.numerals serif -look.weight light -look.corners sharp
