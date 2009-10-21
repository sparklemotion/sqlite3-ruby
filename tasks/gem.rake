require 'rubygems/package_task'
require 'hoe'

HOE = Hoe.spec 'sqlite3-ruby' do
  self.rubyforge_name = 'sqlite-ruby'
  self.need_tar       = true
  self.need_zip       = true

  developer           'Jamis Buck', 'jamis@37signals.com'
  developer           'Luis Lavena', 'luislavena@gmail.com'

  spec_extras[:required_ruby_version] = Gem::Requirement.new('> 1.8.5')
  spec_extras[:required_rubygems_version] = '1.3.5'

  spec_extras[:extensions] = ["ext/sqlite3_api/extconf.rb"]

  extra_dev_deps << ['mocha', "~> 0.9.8"]
  extra_dev_deps << ['rake-compiler', "~> 0.6.0"]

  spec_extras[:rdoc_options] = proc do |rdoc_options|
    rdoc_options << "--exclude" << "ext"
  end

  clean_globs.push('**/test.db')
end
