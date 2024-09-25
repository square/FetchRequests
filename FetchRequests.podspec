Pod::Spec.new do |s|
  s.name = 'FetchRequests'
  s.version = '7.0.1'
  s.license = 'MIT'
  s.summary = 'NSFetchedResultsController inspired eventing'
  s.homepage = 'https://github.com/square/FetchRequests'
  s.authors = 'Square'
  s.source = { :git => 'https://github.com/square/FetchRequests.git', :tag => s.version }

  ios_deployment_target = '14.0'
  tvos_deployment_target = '14.0'
  watchos_deployment_target = '7.0'
  macos_deployment_target = '11'
  visionos_deployment_target = '1'

  s.ios.deployment_target = ios_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target
  s.macos.deployment_target = macos_deployment_target
  s.visionos.deployment_target = visionos_deployment_target

  s.swift_versions = ['5.0', '6.0']

  s.source_files = [
    'FetchRequests/simplediff-swift/simplediff.swift',
    'FetchRequests/Sources/**/*.swift',
  ]

  s.test_spec do |test_spec|
    test_spec.source_files = 'FetchRequests/Tests/**/*.swift'

    test_spec.ios.deployment_target = ios_deployment_target
    test_spec.tvos.deployment_target = tvos_deployment_target
    test_spec.watchos.deployment_target = watchos_deployment_target
    test_spec.macos.deployment_target = macos_deployment_target
    test_spec.visionos.deployment_target = visionos_deployment_target
  end

end
