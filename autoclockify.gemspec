
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "autoclockify/version"

Gem::Specification.new do |spec|
  spec.name          = "autoclockify"
  spec.version       = Autoclockify::VERSION
  spec.authors       = ["Andrew MacDonald"]
  spec.email         = ["andrew@getreal.band"]

  spec.summary       = %q{Automatically clockify git hours}
  spec.description   = %q{Automatically log git commits and time spent in branches in Clockify}
  spec.homepage      = "https://andrewjmacdonald.ca"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://andrewjmacdonald.ca"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/ajmd17/auto-clockify"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "httparty"
  spec.add_development_dependency "memoist"
  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "byebug"
end
