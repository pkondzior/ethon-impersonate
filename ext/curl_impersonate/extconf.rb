# frozen_string_literal: true
require "mkmf"
require "fileutils"

# Directory layout
ROOT_DIR = File.expand_path("../..", __dir__)
VENDOR_DIR = File.join(ROOT_DIR, "vendor", "curl-impersonate")
EXT_DIR = File.join(ROOT_DIR, "ext")
BUILD_DIR = File.join(ROOT_DIR, "tmp", "build", "native")
INSTALL_DIR = File.join(ROOT_DIR, "tmp", "install", "native")

def make_cmd
  RbConfig::CONFIG["host_os"] =~ /darwin/ ? "gmake" : "make"
end

def lib_glob
  case RbConfig::CONFIG["host_os"]
  when /darwin/
    "libcurl-impersonate*.dylib"
  when /linux/
    "libcurl-impersonate*.so*"
  else
    abort "Unsupported OS: #{RbConfig::CONFIG["host_os"]}"
  end
end

def shared_libs_present?
  Dir.glob(File.join(EXT_DIR, lib_glob)).any? do |f|
    !File.symlink?(f) || File.exist?(f)
  end
end

# Skip build if shared libraries are already in ext/ (e.g. platform-specific gem)
if shared_libs_present?
  $stderr.puts "curl-impersonate shared libraries already present in ext/, skipping build."
  # Create a dummy Makefile so `make` is a no-op
  File.write("Makefile", "all:\n\techo 'Already built'\ninstall:\n\techo 'Already installed'\n")
  exit 0
end

unless File.exist?(File.join(VENDOR_DIR, "configure.ac"))
  abort <<~MSG
    curl-impersonate source not found at #{VENDOR_DIR}.
    If you installed this gem from GitHub, make sure to init submodules:
      git submodule update --init --recursive
  MSG
end

FileUtils.mkdir_p(BUILD_DIR)
FileUtils.mkdir_p(INSTALL_DIR)

# Generate configure script if needed
unless File.exist?(File.join(VENDOR_DIR, "configure"))
  $stderr.puts "Running autoreconf..."
  system("cd #{VENDOR_DIR} && autoreconf -fi") || abort("autoreconf failed")
end

# Configure (only once)
unless File.exist?(File.join(BUILD_DIR, "Makefile"))
  $stderr.puts "Configuring curl-impersonate..."
  system("cd #{BUILD_DIR} && #{VENDOR_DIR}/configure --prefix=#{INSTALL_DIR}") || abort("configure failed")
end

# Build
$stderr.puts "Building curl-impersonate (this may take a while)..."
system("cd #{BUILD_DIR} && #{make_cmd} build") || abort("build failed")

# Install
$stderr.puts "Installing curl-impersonate..."
system("cd #{BUILD_DIR} && #{make_cmd} install DESTDIR=") || abort("install failed")

# Copy shared libraries to ext/
lib_dir = File.join(INSTALL_DIR, "lib")
copied = false

Dir.glob(File.join(lib_dir, "libcurl-impersonate*")).each do |src|
  next if src.end_with?(".a", ".la")
  dest = File.join(EXT_DIR, File.basename(src))
  FileUtils.cp(src, dest, verbose: true)
  copied = true
end

abort("No shared libraries found in #{lib_dir}") unless copied

# Create a dummy Makefile — the real work is done above
File.write("Makefile", "all:\n\techo 'Build complete'\ninstall:\n\techo 'Install complete'\n")
