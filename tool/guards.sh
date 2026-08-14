#!/usr/bin/env bash
#
# The checks CLAUDE.md asks to be automated (see its closing section). Each one
# exists because a real bug got through review without it.
#
# Run from the repo root: ./tool/guards.sh
set -uo pipefail

failed=0
check() { # check <name> <explanation-on-failure>
  if [ "$2" = "" ]; then
    printf '  ✓ %s\n' "$1"
  else
    printf '  ✗ %s\n     %s\n' "$1" "$2"
    failed=1
  fi
}

echo "== §7.1 business logic must not depend on Flutter =="
# Deliberately an allow-list, not a `core/` path match: a directory-name grep
# passes vacuously when the directory doesn't exist, which is worse than no check.
offenders=$(grep -rlE '^import io\.flutter' android/src/main/kotlin/ 2>/dev/null \
  | grep -v 'FlutterCompressPlugin.kt' || true)
check "Kotlin engines are Flutter-free" "${offenders:+leaked into: $offenders}"

offenders=$(grep -rlE '^import Flutter' ios/flutter_compress/Sources/ 2>/dev/null \
  | grep -v 'FlutterCompressPlugin.swift' || true)
check "Swift engines are Flutter-free" "${offenders:+leaked into: $offenders}"

echo "== §7.2 / §7.3 no force-unwrapping =="
offenders=$(grep -rnE '[a-zA-Z0-9_)\]]!!' android/src/main/kotlin/ 2>/dev/null || true)
check "no Kotlin '!!'" "${offenders:+$offenders}"

offenders=$(grep -rnE ' as! | try! ' ios/flutter_compress/Sources/ 2>/dev/null || true)
check "no Swift 'as!' / 'try!'" "${offenders:+$offenders}"

echo "== §7.2 no unstructured concurrency =="
offenders=$(grep -rnE 'GlobalScope|runBlocking' android/src/main/kotlin/ 2>/dev/null || true)
check "no GlobalScope / runBlocking" "${offenders:+$offenders}"

echo "== §11.2 web must use dart:js_interop =="
offenders=$(grep -rnE "import 'dart:(html|js|js_util)'" lib/ 2>/dev/null || true)
check "no dart:html / dart:js" "${offenders:+$offenders}"

echo "== §6.4 privacy manifest is present AND packaged =="
manifest=ios/flutter_compress/Sources/flutter_compress/PrivacyInfo.xcprivacy
[ -f "$manifest" ] && r="" || r="missing $manifest"
check "manifest exists" "$r"
# Listing it in source_files does not package it — resource_bundles is required.
grep -qE '^\s*s\.resource_bundles' ios/flutter_compress.podspec && r="" \
  || r="podspec does not declare resource_bundles"
check "packaged via podspec resource_bundles" "$r"
grep -qE '\.process\("PrivacyInfo\.xcprivacy"\)' ios/flutter_compress/Package.swift && r="" \
  || r="Package.swift does not .process() it"
check "packaged via SPM resources" "$r"

echo "== §6.2.3 consumer R8 rules are shipped, not just present =="
[ -f android/consumer-rules.pro ] && r="" || r="missing android/consumer-rules.pro"
check "consumer-rules.pro exists" "$r"
grep -q 'consumerProguardFiles' android/build.gradle.kts && r="" \
  || r="build.gradle.kts never references it, so the file is inert"
check "wired via consumerProguardFiles" "$r"

echo "== §3.4 error codes identical on all three platforms =="
d=$(grep -oE "'[a-z_]+'" lib/src/error_codes.dart | tr -d "'" | sort -u)
k=$(grep -oE '"[a-z_]+"' android/src/main/kotlin/com/compress/all/flutter_compress/ErrorCode.kt | tr -d '"' | sort -u)
i=$(grep -oE '"[a-z_]+"' ios/flutter_compress/Sources/flutter_compress/ErrorCode.swift | tr -d '"' | sort -u)
if [ "$d" = "$k" ] && [ "$d" = "$i" ]; then r=""; else
  r="Dart/Kotlin/Swift sets differ:
$(diff <(echo "$d") <(echo "$k") | sed 's/^/       kotlin: /')
$(diff <(echo "$d") <(echo "$i") | sed 's/^/       swift:  /')"
fi
check "code sets match" "$r"

echo "== version is consistent across pubspec / podspec / README =="
v=$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}')
grep -q "s.version *= *'$v'" ios/flutter_compress.podspec && r="" \
  || r="podspec is not $v"
check "podspec matches pubspec ($v)" "$r"
grep -q "flutter_compress: \^$v" README.md && r="" || r="README.md is not ^$v"
check "README matches pubspec" "$r"

echo
[ $failed -eq 0 ] && echo "All guards passed." || echo "Some guards failed."
exit $failed
