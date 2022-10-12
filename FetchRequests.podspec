Pod::Spec.new do |s|
  s.name = 'FetchRequests'
  s.version = '4.0.4'
  s.license = 'MIT'
  s.summary = 'NSFetchedResultsController inspired eventing'
  s.homepage = 'https://github.com/square/FetchRequests'
  s.authors = 'Square'
  s.source = { :git => 'https://github.com/square/FetchRequests.git', :tag => s.version }

  ios_deployment_target = '13.0'
  tvos_deployment_target = '13.0'
  macos_deployment_target = '10.15'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target
  s.macos.deployment_target = macos_deployment_target

  s.swift_version = '5.0'

  s.source_files = [
    'FetchRequests/simplediff-swift/simplediff.swift',
    'FetchRequests/Sources/**/*.swift',
  ]

  s.test_spec do |test_spec|
    test_spec.source_files = 'FetchRequests/Tests/**/*.swift'

    test_spec.ios.deployment_target = ios_deployment_target
    test_spec.watchos.deployment_target = watchos_deployment_target
    test_spec.tvos.deployment_target = tvos_deployment_target
    test_spec.macos.deployment_target = macos_deployment_target
  end

end
