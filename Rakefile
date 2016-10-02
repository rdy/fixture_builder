require 'bundler'
include Rake::DSL if defined?(Rake::DSL)
Bundler::GemHelper.install_tasks

require 'rake/testtask'
Rake::TestTask.new(:run_test) do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = false
end

task :test do
  begin
    Rake::Task[:run_test].execute
  ensure
    Rake::Task[:dbdrop].invoke
  end
end

require 'pg'
task :dbcreate do
  PG.connect(dbname: 'postgres').exec("CREATE DATABASE testdb")
end

task :dbdrop do
  PG.connect(dbname: 'postgres').exec("DROP DATABASE testdb")
end

task :test => :dbcreate

task :default => :test
