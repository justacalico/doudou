Pod::Spec.new do |s|
  s.name             = 'AudiotagsStub'
  s.version          = '1.0.0'
  s.summary          = 'Stub implementations for audiotags missing symbols'
  s.description      = 'Provides stub C functions for audiotags flutter_rust_bridge symbols that are missing from the iOS xcframework'
  s.homepage         = 'https://gitlab.com/Openlyst/doudou'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Openlyst' => 'dev@openlyst.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'AudiotagsStub.c'
  s.platform         = :ios, '13.0'
end
