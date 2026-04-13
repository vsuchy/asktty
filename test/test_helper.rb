# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "asktty"
require "io/wait"
require "json"
require "minitest/autorun"
require "open3"
require "pty"
require "rbconfig"

module AskTTYIntegration
  Execution = Struct.new(:value, :error, :output, :status, keyword_init: true)

  LIB_PATH = File.expand_path("../lib", __dir__)
  MARKER_PATTERN = /__ASKTTY_(RESULT|ERROR)__=([A-Fa-f0-9]+)/

  private_constant :LIB_PATH, :MARKER_PATTERN

  private

  def run_asktty(code, input_chunks: [], tty: false, timeout: 5)
    child_code = <<~RUBY
      require "asktty"
      require "json"

      def serialize_for_test(value)
        case value
        when Array
          { "type" => "array", "value" => value.map { |item| serialize_for_test(item) } }
        when Hash
          { "type" => "hash", "value" => value.transform_values { |item| serialize_for_test(item) } }
        when Symbol
          { "type" => "symbol", "value" => value.to_s }
        else
          { "type" => "raw", "value" => value }
        end
      end

      begin
        result = begin
          #{code}
        end

        STDOUT.puts "\n__ASKTTY_RESULT__=\#{JSON.dump(serialize_for_test(result)).unpack1('H*')}"
      rescue StandardError => error
        payload = { class: error.class.name, message: error.message }
        STDOUT.puts "\n__ASKTTY_ERROR__=\#{JSON.dump(serialize_for_test(payload)).unpack1('H*')}"
        exit 1
      end
    RUBY

    tty ? run_in_pty(child_code, input_chunks:, timeout:) : run_without_tty(child_code)
  end

  def run_in_pty(child_code, input_chunks:, timeout:)
    output = +""
    reader, writer, pid = PTY.spawn(RbConfig.ruby, "-I#{LIB_PATH}", "-e", child_code)

    warm_up_prompt(reader, output)

    input_chunks.each do |chunk|
      begin
        writer.write(chunk)
        writer.flush
      rescue Errno::EIO, Errno::EPIPE
        break
      end

      sleep 0.05
      drain_output(reader, output)
    end

    writer.close unless writer.closed?
    status = wait_for_process(pid, reader, output, timeout:)

    build_execution(output, status)
  ensure
    writer&.close unless writer&.closed?
    reader&.close unless reader&.closed?
  end

  def run_without_tty(child_code)
    output, status = Open3.capture2e(RbConfig.ruby, "-I#{LIB_PATH}", "-e", child_code)

    build_execution(output, status)
  end

  def assert_successful_run(execution)
    assert_predicate execution.status, :success?, "expected subprocess to succeed\n#{execution.output}"
    assert_nil execution.error, "expected no error payload\n#{execution.output}"
  end

  def assert_public_error(execution, class_name:, message:)
    assert_equal class_name, execution.error[:class]
    assert_equal message, execution.error[:message]
    refute_predicate execution.status, :success?, "expected subprocess to fail\n#{execution.output}"
    refute_nil execution.error, "expected an error payload\n#{execution.output}"
  end

  def build_execution(output, status)
    marker, encoded_payload = output.scan(MARKER_PATTERN).last
    payload = encoded_payload ? deserialize_payload(JSON.parse([encoded_payload].pack("H*"))) : nil

    Execution.new(
      value: marker == "RESULT" ? payload : nil,
      error: marker == "ERROR" ? payload : nil,
      output: output,
      status: status
    )
  end

  def deserialize_payload(payload)
    case payload.fetch("type")
    when "array"
      payload.fetch("value").map { |item| deserialize_payload(item) }
    when "hash"
      payload.fetch("value").transform_values { |item| deserialize_payload(item) }.transform_keys(&:to_sym)
    when "symbol"
      payload.fetch("value").to_sym
    else
      payload["value"]
    end
  end

  def drain_output(reader, output)
    loop do
      output << reader.read_nonblock(4096)
    end
  rescue IO::WaitReadable, EOFError, Errno::EIO
    output
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def warm_up_prompt(reader, output)
    deadline = monotonic_time + 0.5

    until monotonic_time >= deadline || !output.empty?
      ready = reader.wait_readable(0.05)
      next unless ready

      drain_output(reader, output)
    end
  end

  def wait_for_process(pid, reader, output, timeout:)
    deadline = monotonic_time + timeout

    loop do
      drain_output(reader, output)

      waited_pid, status = Process.waitpid2(pid, Process::WNOHANG)
      return status if waited_pid

      if monotonic_time >= deadline
        Process.kill("TERM", pid)
        Process.waitpid(pid)

        flunk "prompt subprocess timed out\n#{output}"
      end

      sleep 0.05
    rescue Errno::ECHILD
      flunk "prompt subprocess exited unexpectedly\n#{output}"
    end
  ensure
    drain_output(reader, output)
  end
end

module Minitest
  class Test
    include AskTTYIntegration
  end
end
