namespace :spec do
  namespace :fixture_builder do
    desc "Deletes the generated fixtures in spec/fixtures"
    task :clean do
      FileUtils.rm_f("tmp/fixture_builder.yml")
      FileUtils.rm_f(Dir.glob('spec/fixtures/*.yml'))
      puts "Automatically generated fixtures removed"
    end

    # These tasks don't work properly in rspec2 yet, removing for now
    # desc "Build the generated fixtures to spec/fixtures if dirty"
    # task :build do
    #   puts "Building automatically generated fixtures..."
    #   raise "Could not rebuild fixtures by running empty specs, look in /tmp/nothing.spec.out" unless system("rake spec:nothing > /tmp/nothing.spec.out")
    # end
    # 
    # desc "Clean and rebuild the generated fixtures to spec/fixtures"
    # task :rebuild => [:clean, :build]
  end

  # Spec::Rake::SpecTask.new(:nothing) do |t|
  #   t.spec_files = FileList["spec/spec_helper.rb"]
  # end
end
