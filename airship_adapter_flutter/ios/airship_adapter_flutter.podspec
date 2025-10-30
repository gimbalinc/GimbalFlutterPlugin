#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint airship_adapter_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'airship_adapter_flutter'
  s.version          = '1.0.0'
  s.summary          = 'Flutter bridge for Gimbal + Airship Adapter'
  s.description      = 'Bridges the GimbalAirshipAdapter iOS SDK for Flutter'
  s.homepage         = 'https://infillion.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rafia Rashid' => 'rafia.rashid@infillion.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.dependency 'GimbalAirshipAdapter', '~> 4.3.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
