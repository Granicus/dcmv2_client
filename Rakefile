require 'rspec/core/rake_task'
require 'dotenv/tasks'

RSpec::Core::RakeTask.new(:spec)
task :default => :spec

task :console => :dotenv do
  exec "irb -r dcmv2 -I ./lib"
end

