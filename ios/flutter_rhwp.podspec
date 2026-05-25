#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_rhwp.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_rhwp'
  s.version          = '2026.5.24'
  s.summary          = 'Flutter bindings and widgets for rhwp.'
  s.description      = <<-DESC
Flutter bindings and widgets for rhwp.
                       DESC
  s.homepage         = 'https://github.com/JAICHANGPARK/flutter_rhwp'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutter_rhwp contributors' => 'noreply@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../rust flutter_rhwp',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libflutter_rhwp.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libflutter_rhwp.a',
  }
end
