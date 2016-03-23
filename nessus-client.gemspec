Gem::Specification.new do |s|
  s.name        = 'nessus-client'
  s.version     = '0.0.1'
  s.license     = 'MIT License'
  s.summary     = 'Tooling for interacting with Nessus 6 API'
  s.description = 'Tooling for provisioning and manag'
  s.authors     = [
    'Peter Wolanin <peter.wolanin@acquia.com>',
  ]
  s.email       = 'cloud-team@acquia.com'
  s.files       = Dir['lib/**/*.rb'] + Dir['assets/*'] + Dir['bin/*']
  s.executables << 'nessus'
  s.homepage    = 'https://github.com/acquia/nessus-client'
  s.required_ruby_version = '>= 2.1.0'

  s.add_runtime_dependency 'thor', '= 0.19.1'  # Matches fields
  s.add_runtime_dependency 'excon', '~> 0.45' # Matches fields
  s.add_runtime_dependency 'terminal-table', '= 1.4.5' # Matches fields

  # s.add_development_dependency('rspec')
end
