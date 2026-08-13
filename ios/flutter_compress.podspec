#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_compress.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_compress'
  s.version          = '1.4.0'
  s.summary          = 'High-quality Flutter video & image compression with precise target-size control.'
  s.description      = <<-DESC
Video compression via an explicit AVAssetReader/Writer pipeline (not export presets),
enabling precise target-size and bitrate control, HEVC with H.264 fallback, live
progress and cancellation. Image compression via ImageIO with target-size, quality
and lossless modes.
                       DESC
  s.homepage         = 'https://github.com/chenkaiHere/flutter_compress'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'ck'
  s.source           = { :path => '.' }
  s.source_files = 'flutter_compress/Sources/flutter_compress/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # App Store requires third-party SDKs to ship a signed privacy manifest. It has
  # to go through resource_bundles — listing it in source_files does not package it.
  s.resource_bundles = {
    'flutter_compress_privacy' => ['flutter_compress/Sources/flutter_compress/PrivacyInfo.xcprivacy']
  }
end
