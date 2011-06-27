require 'bundler'
include Rake::DSL
Bundler::GemHelper.install_tasks

require 'rake/testtask'
Rake::TestTask.new(:test_all) do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = false
end

task :default => :test_all
