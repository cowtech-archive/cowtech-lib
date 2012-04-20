# encoding: utf-8
#
# This file is part of the cowtech-lib gem. Copyright (C) 2011 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "./lib/cowtech-lib/version"

Gem::Specification.new do |s|
	s.name = "cowtech-lib"
	s.version = Cowtech::Lib::Version::STRING
	s.authors = ["Shogun"]
	s.email = ["shogun_panda@me.com"]
	s.homepage = "http://github.com/ShogunPanda/cowtech-lib"
	s.summary = %q{A general purpose utility library.}
	s.description = %q{A general purpose utility library.}

	s.rubyforge_project = "cowtech-lib"
	s.files = `git ls-files`.split("\n")
	s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
	s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
	s.require_paths = ["lib"]

	s.required_ruby_version = ">= 1.9.2"
	s.add_dependency "open4"
end


