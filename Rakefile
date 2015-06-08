require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "yard"
require "yard/rake/yardoc_task"

RSpec::Core::RakeTask.new(:spec)
YARD::Rake::YardocTask.new do |t|
  t.files = FileList["lib/**/*.rb"]
  t.options = ['--embed-mixins']
#  t.stats_options = ['--list-undoc']
end

task :default => :spec

