#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p .build/regression-checks
swiftc \
	-parse-as-library \
	SnapMark/LayoutRules.swift \
	Tests/SnapMarkRegressionChecks/main.swift \
	-o .build/regression-checks/SnapMarkRegressionChecks

.build/regression-checks/SnapMarkRegressionChecks