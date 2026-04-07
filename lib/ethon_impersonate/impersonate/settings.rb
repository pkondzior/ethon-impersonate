# frozen_string_literal: true
require "rbconfig"
require "fileutils"
require "ffi/platform"

module EthonImpersonate
  module Impersonate
    module Settings
      LIB_VERSION = "1.5.2"
      LIB_EXT_PATH = File.expand_path("../../ext/", File.dirname(__dir__))

      LIB_OS_FULL_NAME_MAP = {
        "linux" => ["libcurl-impersonate.so", "libcurl-impersonate.so.4"],
        "darwin" => ["libcurl-impersonate.dylib", "libcurl-impersonate.4.dylib"],
        "windows" => ["libcurl.dll", "libcurl-impersonate.dll"],
      }.freeze

      # Platforms supported for building from source
      LIB_PLATFORM_RELEASE_MAP = {
        "aarch64-darwin" => "aarch64-darwin",
        "x86_64-linux" => "x86_64-linux",
        "x86_64-darwin" => "x86_64-darwin",
      }.freeze

      GEM_PLATFORMS_MAP = {
        "aarch64-darwin" => ["arm64-darwin-24", "arm64-darwin"],
        "x86_64-darwin" => ["x86_64-darwin-24"],
        "x86_64-windows" => ["x64-mingw32"],
      }.freeze

      def self.ffi_libs
        libraries = []

        if ENV["CURL_IMPERSONATE_LIBRARY"]
          libraries << ENV["CURL_IMPERSONATE_LIBRARY"]
        end

        if lib_names.nil? || lib_names.empty?
          abort "Unsupported architecture/OS combination: #{arch_os}"
        end

        libraries += lib_names
        libraries += lib_names.map { |lib_name| File.join(LIB_EXT_PATH, lib_name) }

        libraries
      end

      def self.lib_names(target_os = nil)
        target_os ||= FFI::Platform::OS
        names = LIB_OS_FULL_NAME_MAP[target_os]

        if names.nil?
          abort "Unsupported OS: #{target_os}"
        end

        names
      end

      def self.arch_os
        "#{FFI::Platform::ARCH}-#{FFI::Platform::OS}"
      end
    end
  end
end
