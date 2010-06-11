gem 'test-unit', '1.2.3' if RUBY_VERSION.to_f >= 1.9
rspec_gem_dir = nil
Dir["#{RAILS_ROOT}/vendor/gems/*"].each do |subdir|
  rspec_gem_dir = subdir if subdir.gsub("#{RAILS_ROOT}/vendor/gems/", "") =~ /^(\w+-)?rspec-(\d+)/ && File.exist?("#{subdir}/lib/spec/rake/spectask.rb")
end
rspec_plugin_dir = File.expand_path(File.dirname(__FILE__) + '/../../vendor/plugins/rspec')

if rspec_gem_dir && (test ?d, rspec_plugin_dir)
  raise "\n#{'*'*50}\nYou have rspec installed in both vendor/gems and vendor/plugins\nPlease pick one and dispose of the other.\n#{'*'*50}\n\n"
end

if rspec_gem_dir
  $LOAD_PATH.unshift("#{rspec_gem_dir}/lib")
elsif File.exist?(rspec_plugin_dir)
  $LOAD_PATH.unshift("#{rspec_plugin_dir}/lib")
end

# Don't load rspec if running "rake gems:*"
unless ARGV.any? {|a| a =~ /^gems/}

  begin
    require 'spec/rake/spectask'
  rescue MissingSourceFile
    module Spec
      module Rake
        class SpecTask
          def initialize(name)
            task name do
              # if rspec-rails is a configured gem, this will output helpful material and exit ...
              require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

              # ... otherwise, do this:
              raise <<-MSG

#{"*" * 80}
*  You are trying to run an rspec rake task defined in
*  #{__FILE__},
*  but rspec can not be found in vendor/gems, vendor/plugins or system gems.
#{"*" * 80}
              MSG
            end
          end
        end
      end
    end
  end

  namespace :spec do
    namespace :fixture_builder do
      desc "Deletes the generated fixtures in spec/fixtures"
      task :clean do
        FileUtils.rm_f("tmp/fixture_builder.yml")
        FileUtils.rm_f(Dir.glob('spec/fixtures/*.yml'))
        puts "Automatically generated fixtures removed"
      end

      desc "Build the generated fixtures to spec/fixtures if dirty"
      task :build do
        puts "Building automatically generated fixtures..."
        raise "Could not rebuild fixtures by running empty specs, look in /tmp/nothing.spec.out" unless system("rake spec:nothing > /tmp/nothing.spec.out")
      end

      desc "Clean and rebuild the generated fixtures to spec/fixtures"
      task :rebuild => [:clean, :build]
    end

    Spec::Rake::SpecTask.new(:nothing) do |t|
      t.spec_files = FileList["spec/spec_helper.rb"]
    end
  end
end
