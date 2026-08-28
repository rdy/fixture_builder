# frozen_string_literal: true

require "bundler/setup"
require "active_support"
require "fileutils"
require "fixture_builder"

$stdout.sync = true

root, role, scenario = ARGV
source_path = File.join(root, "source.rb")
fixture_directory = File.join(root, "fixtures")
fixture_path = File.join(fixture_directory, "records.yml")
manifest_path = if scenario == "shared_fixture"
  File.join(root, "state", "fixture_builder-#{role}.yml")
else
  File.join(root, "state", "fixture_builder.yml")
end
marker_path = File.join(root, "builds.log")
event_path = File.join(root, "events.log")
preflight_path = File.join(root, "preflight.log")
release_path = File.join(root, "release.log")

class FixtureBuilder::Builder
  def generate!
    @builder_block.call
    @configuration.after_build&.call
    self
  end
end

def append_line(path, line)
  File.open(path, File::RDWR | File::CREAT | File::APPEND) do |file|
    file.flock(File::LOCK_EX)
    first_line = file.size.zero?
    file.puts(line)
    file.flush
    file.fsync
    first_line
  end
end

def wait_for_lines(path, count)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
  until File.exist?(path) && File.readlines(path).length >= count
    if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      raise "timed out waiting for #{count} lines in #{path}"
    end

    sleep 0.01
  end
end

def configuration_for(source_path, fixture_directory, manifest_path, event_path, role)
  configuration = FixtureBuilder::Configuration.new
  configuration.files_to_check = [source_path]
  configuration.fixture_directory = fixture_directory
  configuration.fixture_builder_file = manifest_path
  instrumentation = Module.new do
    define_method(:invalidate_config) do
      append_line(event_path, "#{role}:enter")
      super()
    end

    define_method(:write_config) do
      super()
      append_line(event_path, "#{role}:exit")
    end
  end
  configuration.singleton_class.prepend(instrumentation)
  configuration
end

def write_fixture(fixture_path, role)
  File.write(
    fixture_path,
    {"record" => {"worker" => role, "pid" => Process.pid}}.to_yaml
  )
end

if scenario == "fork_threads"
  prime = FixtureBuilder::Configuration.new
  prime.files_to_check = [source_path]
  prime.fixture_directory = fixture_directory
  prime.fixture_builder_file = manifest_path
  prime.factory { write_fixture(fixture_path, "parent") }
  FileUtils.rm(manifest_path)

  child_pid = fork do
    thread_count = 8
    configurations = thread_count.times.map do |index|
      thread_role = "child-#{index}"
      configuration = configuration_for(
        source_path,
        fixture_directory,
        manifest_path,
        event_path,
        thread_role
      )
      barrier = Module.new do
        define_method(:rebuild_fixtures?) do |*args, **kwargs|
          result = kwargs.empty? ? super(*args) : super(*args, **kwargs)
          append_line(preflight_path, thread_role)
          wait_for_lines(preflight_path, thread_count)
          result
        end
      end
      configuration.singleton_class.prepend(barrier)
      [thread_role, configuration]
    end
    results = Queue.new
    threads = configurations.map do |thread_role, configuration|
      Thread.new do
        configuration.factory do
          append_line(marker_path, "#{thread_role}:#{Process.pid}")
          write_fixture(fixture_path, thread_role)
        end
        results << nil
      rescue => error
        results << error
      end
    end
    threads.each(&:join)
    errors = thread_count.times.filter_map { results.pop }
    raise errors.first if errors.any?

    exit! 0
  rescue => error
    warn error.full_message
    exit! 1
  end
  status = Process.wait2(child_pid).last
  exit status.exitstatus || 1
end

if %w[thread_serialization thread_failure].include?(scenario)
  configurations = %w[one two].to_h do |thread_role|
    configuration = configuration_for(
      source_path,
      fixture_directory,
      manifest_path,
      event_path,
      thread_role
    )
    [thread_role, configuration]
  end
  if scenario == "thread_failure"
    configurations.fetch("one").after_build = proc do
      wait_for_lines(release_path, 1)
      raise "after build failure"
    end
  end

  results = Queue.new
  first = Thread.new do
    configurations.fetch("one").factory do
      append_line(marker_path, "one:#{Process.pid}")
      wait_for_lines(release_path, 1) if scenario == "thread_serialization"
      write_fixture(fixture_path, "one")
    end
    results << ["one", nil]
  rescue => error
    results << ["one", error]
  end
  wait_for_lines(event_path, 1)
  second = Thread.new do
    configurations.fetch("two").factory do
      append_line(marker_path, "two:#{Process.pid}")
      write_fixture(fixture_path, "two")
    end
    results << ["two", nil]
  rescue => error
    results << ["two", error]
  end

  [first, second].each(&:join)
  outcomes = 2.times.to_h { results.pop }
  raise outcomes.fetch("two") if outcomes.fetch("two")

  first_error = outcomes.fetch("one")
  if scenario == "thread_failure"
    raise "first builder unexpectedly succeeded" unless first_error&.message == "after build failure"
  elsif first_error
    raise first_error
  end
  exit
end

configured_fixture_directory = if scenario == "shared_fixture" && role == "waiter"
  File.join(fixture_directory, "..", "fixtures")
else
  fixture_directory
end
configuration = configuration_for(
  source_path,
  configured_fixture_directory,
  manifest_path,
  event_path,
  role
)

if scenario == "source_change"
  barrier = Module.new do
    define_method(:rebuild_fixtures?) do |*args, **kwargs|
      result = kwargs.empty? ? super(*args) : super(*args, **kwargs)
      unless @preflight_barrier_complete
        @preflight_barrier_complete = true
        append_line(preflight_path, role)
        wait_for_lines(preflight_path, 2)
      end
      result
    end
  end
  configuration.singleton_class.prepend(barrier)
elsif scenario == "failing"
  configuration.after_build = proc do
    wait_for_lines(release_path, 1)
    raise "after build failure"
  end
end

configuration.factory do
  first_build = append_line(marker_path, "#{role}:#{Process.pid}")
  File.write(source_path, "changed by #{role}\n") if scenario == "source_change" && first_build
  if scenario == "holding" || (scenario == "shared_fixture" && role == "holder")
    wait_for_lines(release_path, 1)
  end
  write_fixture(fixture_path, role)
end
