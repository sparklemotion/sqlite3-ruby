# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.spec 'sqlite3-ruby' do
  developer           'Jamis Buck', 'jamis@37signals.com'
  developer           'Luis Lavena', 'luislavena@gmail.com'
  developer           'Aaron Patterson', 'aaron@tenderlovemaking.com'

  self.version          = '1.3.3'
  self.readme_file      = 'README.rdoc'
  self.history_file     = 'CHANGELOG.rdoc'
  self.extra_rdoc_files = FileList['*.rdoc']
  extra_deps            << ['sqlite3', '>= 1.3.3']
  self.post_install_message = <<-eomessage

#######################################################

Hello! The sqlite3-ruby gem has changed it's name to just sqlite3.  Rather than
installing `sqlite3-ruby`, you should install `sqlite3`.  Please update your
dependencies accordingly.

Thanks from the Ruby sqlite3 team!

<3 <3 <3 <3

#######################################################

  eomessage
end

# vim: syntax=ruby
