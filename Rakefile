require 'bundler'
include Rake::DSL if defined?(Rake::DSL)
Bundler::GemHelper.install_tasks

require 'rake/testtask'
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = false
end

task :default => :test
