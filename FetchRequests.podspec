Pod::Spec.new do |s|
  s.name = 'FetchRequests'
  s.version = '3.0.1'
  s.license = 'MIT'
  s.summary = 'NSFetchedResultsController inspired eventing'
  s.homepage = 'https://github.com/crewos/FetchRequests'
  s.social_media_url = 'https://twitter.com/crew_app'
  s.authors = { 'Speramus Inc' => 'opensource@crewapp.com' }
  s.source = { :git => 'https://github.com/crewos/FetchRequests.git', :tag => s.version }

  ios_deployment_target = '12.0'
  tvos_deployment_target = '12.0'
  macos_deployment_target = '10.14'
  watchos_deployment_target = '5.0'

  s.ios.deployment_target = ios_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.macos.deployment_target = macos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.swift_version = '5.0'

  s.source_files = [
    'FetchRequests/simplediff-swift/simplediff.swift',
    'FetchRequests/Sources/**/*.swift',
  ]

  s.test_spec do |test_spec|
    test_spec.source_files = 'FetchRequestsTests/**/*.swift'

    # watchOS inherently doesn't support tests
    test_spec.ios.deployment_target = ios_deployment_target
    test_spec.tvos.deployment_target = tvos_deployment_target
    test_spec.macos.deployment_target = macos_deployment_target
  end

end
