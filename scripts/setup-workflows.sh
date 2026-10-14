#!/bin/bash
# scripts/setup-workflows.sh
# Write .github/workflows/test.yml for family repos that do not have one.
# Leaves web-app-893, pdf-search-893, dliv-web, and video-convert-893 alone.
# Does not commit or push.
#
# Usage:
#   ./scripts/setup-workflows.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_PARENT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PARENT="${WORKFLOW_PARENT:-$DEFAULT_PARENT}"

backend_workflow() {
  cat <<'EOF'
name: test

on:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: backend/package-lock.json
      - run: npm ci
      - run: npm test
EOF
}

cognito_workflow() {
  cat <<'EOF'
name: test

on:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/new-site.test.sh
      - run: bash scripts/site-aws.test.sh
      - run: bash scripts/setup-amplify.test.sh
      - run: bash scripts/create-user.test.sh
EOF
}

iphone_simulator_step() {
  cat <<'EOF'
          sim=$(xcrun simctl list devices available | sed -n 's/^ *\(iPhone[^(]*\) (.*/\1/p' | head -1 | sed 's/ *$//')
          test -n "$sim"
EOF
}

music_workflow() {
  cat <<EOF
name: test

on:
  pull_request:

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Unit tests
        run: |
$(iphone_simulator_step)
          ./run_tests.sh "\$sim"
EOF
}

mileage_workflow() {
  cat <<EOF
name: test

on:
  pull_request:

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Unit tests
        run: |
$(iphone_simulator_step)
          xcodebuild test \\
            -project ios/MileageTracker893/MileageTracker893.xcodeproj \\
            -scheme MileageTracker893 \\
            -destination "platform=iOS Simulator,name=\${sim}" \\
            -only-testing:MileageTracker893Tests
EOF
}

write_mileage_scheme() {
  local dest="$1/ios/MileageTracker893/MileageTracker893.xcodeproj/xcshareddata/xcschemes/MileageTracker893.xcscheme"
  if [ -f "$dest" ]; then
    echo "  Scheme already present: ${dest}"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "0C71E5E02FA210FF0070C44B"
               BuildableName = "MileageTracker893.app"
               BlueprintName = "MileageTracker893"
               ReferencedContainer = "container:MileageTracker893.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "0C71E5ED2FA211000070C44B"
               BuildableName = "MileageTracker893Tests.xctest"
               BlueprintName = "MileageTracker893Tests"
               ReferencedContainer = "container:MileageTracker893.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "0C71E5E02FA210FF0070C44B"
            BuildableName = "MileageTracker893.app"
            BlueprintName = "MileageTracker893"
            ReferencedContainer = "container:MileageTracker893.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "0C71E5E02FA210FF0070C44B"
            BuildableName = "MileageTracker893.app"
            BlueprintName = "MileageTracker893"
            ReferencedContainer = "container:MileageTracker893.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
EOF
  echo "  Wrote ${dest}"
}

write_workflow() {
  local repo="$1"
  local kind="$2"
  local dir="${PARENT}/${repo}"
  local file="${dir}/.github/workflows/test.yml"
  if [ ! -d "$dir" ]; then
    echo "  Missing repo folder: ${dir}"
    return 0
  fi
  if [ -f "$file" ]; then
    echo "  Workflow already present: ${repo}"
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  case "$kind" in
    backend) backend_workflow > "$file" ;;
    cognito) cognito_workflow > "$file" ;;
    music) music_workflow > "$file" ;;
    mileage) mileage_workflow > "$file" ;;
  esac
  echo "  Wrote ${file}"
  if [ "$kind" = "mileage" ]; then
    write_mileage_scheme "$dir"
  fi
}

echo "  Parent: ${PARENT}"
write_workflow "cognito-s3-stack-893" cognito
write_workflow "dropbox-893" backend
write_workflow "calendar-893" backend
write_workflow "mileage-expense-tracker-893" mileage
write_workflow "music-player-893" music
echo "  Done. Commit and push dev in each repo that received a workflow."
