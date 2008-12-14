require 'rake/rdoctask'

DOC = Rake::RDocTask.new(:rdoc) do |rd|
  rd.title    = "SQLite3/Ruby"
  rd.main     = 'README.rdoc'
  rd.rdoc_dir = 'api'
  rd.options += %w(--line-numbers --inline-source --main README.rdoc)
  rd.rdoc_files.include %w(README.rdoc lib/**/*.rb)

  # attempt to use jamis RDoc template
  begin
    require 'rdoc/generators/template/html/jamis'
    rd.template = "jamis"
  rescue LoadError
    nil
  end
end

# Generate FAQ
desc "Generate the FAQ document"
task :faq => ['doc/faq/faq.html']

file 'doc/faq/faq.html' => ['doc/faq/faq.rb', 'doc/faq/faq.yml'] do
  cd 'doc/faq' do
    ruby "faq.rb > faq.html"
  end
end
