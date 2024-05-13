# frozen_string_literal: true

require_relative "lib/expense_tracker/version"

Gem::Specification.new do |spec|
  spec.name = "expense_tracker"
  spec.version = ExpenseTracker::VERSION
  spec.authors = ["IgorCSilva"]
  spec.email = ["igor.carneiro.silva13@gmail.com"]

  spec.summary = " Write a short summary, because RubyGems requires one."
  spec.description = " Write a longer description or delete this line."
  spec.homepage = "https://example.com"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://example.com"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://example.com"
  spec.metadata["changelog_uri"] = "https://example.com"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "rspec", "~> 3.6.0"
  spec.add_dependency "coderay", "~> 1.1.1"
  spec.add_dependency "rack-test", "~> 0.7.0"
  spec.add_dependency "sinatra", "~> 2.0.0"
  spec.add_dependency "base64", "~> 0.1.0"
  spec.add_dependency "webrick", "~> 1.8.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
