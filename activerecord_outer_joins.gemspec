$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "activerecord_outer_joins/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "activerecord_outer_joins"
  s.version     = ActiverecordOuterJoins::VERSION
  s.authors     = ["Florian Thomas"]
  s.email       = ["flo@florianthomas.net"]
  s.homepage    = "http://florianthomas.net"
  s.summary     = "Adds ActiveRecord::Relation#outer_joins"
  s.description = "ActiveRecord::Relation#outer_joins"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.0.0"

  s.add_development_dependency "sqlite3"
end
