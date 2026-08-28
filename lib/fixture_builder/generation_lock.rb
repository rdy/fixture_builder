# frozen_string_literal: true

require "fileutils"

module FixtureBuilder
  # standard:disable Rails/Output
  class GenerationLock
    RegistryState = Data.define(:pid, :mutexes)
    private_constant :RegistryState

    @registry_guard = Mutex.new
    @registry_state = RegistryState.new(pid: Process.pid, mutexes: {})

    class << self
      private

      def mutexes_for(lock_paths)
        # MRI resets inherited Mutex ownership after fork, so the registry guard
        # can safely serialize the child process's PID transition.
        @registry_guard.synchronize do
          state = @registry_state
          if state.nil? || state.pid != Process.pid
            state = RegistryState.new(pid: Process.pid, mutexes: {})
            @registry_state = state
          end

          lock_paths.map { |lock_path| state.mutexes[lock_path] ||= Mutex.new }
        end
      end
    end

    def initialize(manifest_lock_path:, fixture_directory:)
      fixture_directory_lock_path = File.join(
        File.expand_path(fixture_directory.to_s),
        ".fixture_builder.lock"
      )
      @lock_paths = [manifest_lock_path.to_s, fixture_directory_lock_path].uniq.sort.freeze
    end

    def synchronize(&block)
      mutexes = self.class.send(:mutexes_for, @lock_paths)
      with_mutexes(mutexes) do
        with_file_locks(&block)
      end
    end

    private

    def with_mutexes(mutexes, index = 0, &block)
      return yield if index == mutexes.length

      lock_path = @lock_paths.fetch(index)
      mutex = mutexes.fetch(index)
      unless mutex.try_lock
        puts "=> waiting for fixture generation lock #{lock_path}"
        mutex.lock
      end

      begin
        with_mutexes(mutexes, index + 1, &block)
      ensure
        mutex.unlock
      end
    end

    def with_file_locks(index = 0, &block)
      return yield if index == @lock_paths.length

      lock_path = @lock_paths.fetch(index)
      FileUtils.mkdir_p(File.dirname(lock_path))
      File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |file|
        unless file.flock(File::LOCK_EX | File::LOCK_NB)
          puts "=> waiting for fixture generation lock #{lock_path}"
          file.flock(File::LOCK_EX)
        end

        begin
          with_file_locks(index + 1, &block)
        ensure
          file.flock(File::LOCK_UN)
        end
      end
    end
  end
  # standard:enable Rails/Output
  private_constant :GenerationLock
end
