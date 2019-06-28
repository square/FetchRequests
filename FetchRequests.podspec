Pod::Spec.new do |s|
  s.name = 'FetchRequests'
  s.version = '1.0.0'
  s.license = 'MIT'
  s.summary = 'NSFetchedResultsController inspired eventing'
  s.homepage = 'https://github.com/speramusinc/FetchRequests'
  s.social_media_url = 'https://twitter.com/crew_app'
  s.authors = { 'Speramus Inc' => 'info@crewapp.com' }
  s.source = { :git => 'https://github.com/speramusinc/FetchRequests.git', :tag => s.version }
  s.documentation_url = 'https://github.com/speramusinc/FetchRequests/blob/master/README.md'

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '3.0'

  s.swift_version = '5.0'

  s.source_files = 'FetchRequests/simplediff-swift/*.swift',
    'FetchRequests/Sources/*.swift',
    'FetchRequests/Sources/*/*.swift'

  s.frameworks = 'CFNetwork'
end
