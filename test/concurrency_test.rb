# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))
require "rbconfig"
require "tmpdir"
require "timeout"

class ConcurrencyTest < Test::Unit::TestCase
  prepend IsolatedFixtureFilesystem

  ConcurrencyHarness = Data.define(:directory) do
    def source_path = File.join(directory, "source.rb")
    def fixture_directory = File.join(directory, "fixtures")
    def fixture_path = File.join(fixture_directory, "records.yml")
    def manifest_path = File.join(directory, "state", "fixture_builder.yml")
    def marker_path = File.join(directory, "builds.log")
    def event_path = File.join(directory, "events.log")
    def release_path = File.join(directory, "release.log")
  end
  WorkerProcess = Data.define(:pid, :log_path)
  WorkerResult = Data.define(:status, :output)

  def test_concurrent_stale_readers_publish_one_fixture_snapshot
    with_concurrency_harness do |harness|
      workers = []
      holder = spawn_worker(harness, "holder", "holding", worker_number: "1")
      workers << holder
      wait_until { File.exist?(harness.marker_path) }
      waiter = spawn_worker(harness, "waiter", "waiter", worker_number: "2")
      workers << waiter
      wait_for_worker_output(waiter, "=> waiting for fixture generation lock")
      File.write(harness.release_path, "release\n")

      results = workers.map { |worker| wait_for_worker(worker) }
      results.each do |result|
        assert_predicate result.status, :success?, result.output
      end
      assert_equal 1, File.readlines(harness.marker_path).length
      assert_include results.last.output, "=> waiting for fixture generation lock"
      assert_manifest_matches_harness(harness)
    ensure
      workers&.each { |worker| terminate_worker(worker) }
    end
  end

  def test_configurations_sharing_fixture_directory_serialize_generation
    with_concurrency_harness do |harness|
      workers = []
      holder = spawn_worker(harness, "holder", "shared_fixture", worker_number: "1")
      workers << holder
      wait_until { generation_events(harness) == ["holder:enter"] }
      waiter = spawn_worker(harness, "waiter", "shared_fixture", worker_number: "2")
      workers << waiter
      wait_for_worker_output(waiter, "=> waiting for fixture generation lock")
      assert_equal ["holder:enter"], generation_events(harness)
      File.write(harness.release_path, "release\n")

      results = workers.map { |worker| wait_for_worker(worker) }
      results.each do |result|
        assert_predicate result.status, :success?, result.output
      end
      assert_equal %w[holder:enter holder:exit waiter:enter waiter:exit],
        generation_events(harness)
      assert_fixture_is_valid(harness)
    ensure
      workers&.each { |worker| terminate_worker(worker) }
    end
  end

  def test_threads_serialize_full_generation_critical_section
    with_concurrency_harness do |harness|
      worker = spawn_worker(harness, "threads", "thread_serialization", worker_number: "1")
      wait_until { generation_events(harness) == ["one:enter"] }
      wait_for_worker_output(worker, "=> waiting for fixture generation lock")
      assert_equal ["one:enter"], generation_events(harness)
      File.write(harness.release_path, "release\n")

      result = wait_for_worker(worker)
      assert_predicate result.status, :success?, result.output
      assert_equal %w[one:enter one:exit], generation_events(harness)
      assert_fixture_is_valid(harness)
    ensure
      terminate_worker(worker) if worker
    end
  end

  def test_thread_waiter_acquires_lock_after_first_builder_raises
    with_concurrency_harness do |harness|
      worker = spawn_worker(harness, "threads", "thread_failure", worker_number: "1")
      wait_until { generation_events(harness) == ["one:enter"] }
      wait_for_worker_output(worker, "=> waiting for fixture generation lock")
      File.write(harness.release_path, "release\n")

      result = wait_for_worker(worker)
      assert_predicate result.status, :success?, result.output
      assert_equal %w[one:enter two:enter two:exit], generation_events(harness)
      assert_fixture_is_valid(harness)
    ensure
      terminate_worker(worker) if worker
    end
  end

  def test_threads_share_one_mutex_registry_after_fork
    with_concurrency_harness do |harness|
      worker = spawn_worker(harness, "fork", "fork_threads", worker_number: "1")
      result = wait_for_worker(worker)

      assert_predicate result.status, :success?, result.output
      assert_equal 1, File.readlines(harness.marker_path).length
      events = generation_events(harness)
      assert_equal 2, events.length
      assert_match(/\Achild-\d+:enter\z/, events.first)
      assert_equal events.first.sub(":enter", ":exit"), events.last
      assert_manifest_matches_harness(harness)
    ensure
      terminate_worker(worker) if worker
    end
  end

  def test_waiter_recomputes_source_hashes_after_acquiring_lock
    with_concurrency_harness do |harness|
      workers = [
        spawn_worker(harness, "one", "source_change", worker_number: "1"),
        spawn_worker(harness, "two", "source_change", worker_number: "2")
      ]
      results = workers.map { |worker| wait_for_worker(worker) }

      results.each do |result|
        assert_predicate result.status, :success?, result.output
      end
      assert_equal 2, File.readlines(harness.marker_path).length
      assert_manifest_matches_harness(harness)
    ensure
      workers&.each { |worker| terminate_worker(worker) }
    end
  end

  def test_waiter_rebuilds_after_first_builder_fails
    with_concurrency_harness do |harness|
      workers = []
      failing_worker = spawn_worker(harness, "failing", "failing", worker_number: "1")
      workers << failing_worker
      wait_until { File.exist?(harness.marker_path) }
      waiter = spawn_worker(harness, "waiter", "waiter", worker_number: "2")
      workers << waiter
      wait_for_worker_output(waiter, "=> waiting for fixture generation lock")
      File.write(harness.release_path, "release\n")

      failing_result = wait_for_worker(failing_worker)
      waiter_result = wait_for_worker(waiter)

      assert_false failing_result.status.success?, failing_result.output
      assert_predicate waiter_result.status, :success?, waiter_result.output
      assert_equal 2, File.readlines(harness.marker_path).length
      assert_include waiter_result.output, "=> waiting for fixture generation lock"
      assert_manifest_matches_harness(harness)
    ensure
      workers&.each { |worker| terminate_worker(worker) }
    end
  end

  private

  def with_concurrency_harness
    Dir.mktmpdir("fixture-builder-concurrency") do |directory|
      harness = ConcurrencyHarness.new(directory: directory)
      FileUtils.mkdir_p(harness.fixture_directory)
      File.write(harness.source_path, "source\n")
      yield harness
    end
  end

  def spawn_worker(harness, role, scenario, worker_number:)
    log_path = File.join(harness.directory, "#{role}.log")
    pid = Process.spawn(
      {"TEST_ENV_NUMBER" => worker_number},
      RbConfig.ruby,
      "-I",
      Rails.root.join("lib").to_s,
      Rails.root.join("test/support/concurrency_worker.rb").to_s,
      harness.directory,
      role,
      scenario,
      chdir: Rails.root.to_s,
      out: log_path,
      err: [:child, :out]
    )
    WorkerProcess.new(pid: pid, log_path: log_path)
  end

  def wait_for_worker(worker)
    status = Timeout.timeout(30) { Process.wait2(worker.pid).last }
    WorkerResult.new(status: status, output: File.read(worker.log_path))
  rescue Timeout::Error
    terminate_worker(worker)
    flunk "worker #{worker.pid} timed out: #{File.read(worker.log_path)}"
  end

  def terminate_worker(worker)
    return if Process.waitpid(worker.pid, Process::WNOHANG)

    Process.kill("TERM", worker.pid)
    Process.wait(worker.pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  def wait_until
    Timeout.timeout(30) do
      sleep 0.01 until yield
    end
  end

  def wait_for_worker_output(worker, content)
    wait_until do
      File.exist?(worker.log_path) && File.read(worker.log_path).include?(content)
    end
  end

  def generation_events(harness)
    return [] unless File.exist?(harness.event_path)

    File.readlines(harness.event_path, chomp: true)
  end

  def assert_fixture_is_valid(harness)
    fixture = YAML.safe_load_file(harness.fixture_path)
    assert_equal ["record"], fixture.keys
    assert_kind_of String, fixture.dig("record", "worker")
  end

  def assert_manifest_matches_harness(harness)
    assert_fixture_is_valid(harness)

    manifest = YAML.safe_load_file(harness.manifest_path)
    assert_equal 1, manifest.fetch("version")
    assert_equal Digest::SHA256.file(harness.source_path).hexdigest,
      manifest.fetch("sources").fetch(harness.source_path)
    assert_equal Digest::SHA256.file(harness.fixture_path).hexdigest,
      manifest.fetch("fixtures").fetch(File.basename(harness.fixture_path))
  end
end
