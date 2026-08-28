# frozen_string_literal: true

require "bundler"
Bundler::GemHelper.install_tasks

require "rake/testtask"
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList["test/*_test.rb"]
  t.verbose = false
end

require "standard/rake"

task default: %i[test standard]
