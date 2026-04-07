# frozen_string_literal: true
require "bundler"
Bundler.setup

require "rake"
require "rspec/core/rake_task"
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "ethon_impersonate/version"
require "ethon_impersonate/impersonate/settings"

require "fileutils"
require "open-uri"
require "rubygems/package"
require "zlib"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.verbose = false
  t.ruby_opts = "-W -I./spec -rspec_helper"
end

desc "Start up the test servers"
task :start do
  require_relative 'spec/support/boot'
  begin
    Boot.start_servers(:rake)
  rescue Exception
  end
end

namespace :ethon_impersonate do
  VENDOR_DIR = File.expand_path("vendor/curl-impersonate", __dir__)

  def make_cmd
    RUBY_PLATFORM =~ /darwin/ ? "gmake" : "make"
  end

  desc "Build libcurl-impersonate from vendored source for a specific arch_os target"
  task :build_from_source, [:arch_os] do |t, args|
    abort("Please provide an arch_os target (e.g., x86_64-linux)") unless args[:arch_os]

    arch_os = args[:arch_os]
    os_target = arch_os.split("-").last
    ext_path = EthonImpersonate::Impersonate::Settings::LIB_EXT_PATH
    lib_names = EthonImpersonate::Impersonate::Settings.lib_names(os_target)

    build_dir = File.expand_path("tmp/build/#{arch_os}", __dir__)
    install_dir = File.expand_path("tmp/install/#{arch_os}", __dir__)

    FileUtils.mkdir_p(build_dir)
    FileUtils.mkdir_p(install_dir)
    FileUtils.mkdir_p(ext_path)

    Dir.glob("ext/libcurl*").each { |path| FileUtils.rm_rf(path) }

    unless File.exist?(File.join(VENDOR_DIR, "configure"))
      puts "Running autoreconf in vendored curl-impersonate..."
      sh("cd #{VENDOR_DIR} && autoreconf -fi")
    end

    unless File.exist?(File.join(build_dir, "Makefile"))
      puts "Configuring curl-impersonate for #{arch_os}..."
      sh("cd #{build_dir} && #{VENDOR_DIR}/configure --prefix=#{install_dir}")
    end

    puts "Building curl-impersonate (this may take a while)..."
    sh("cd #{build_dir} && #{make_cmd} build")

    puts "Installing to #{install_dir}..."
    sh("cd #{build_dir} && #{make_cmd} install DESTDIR=")

    # Copy shared libraries to ext/
    lib_dir = File.join(install_dir, "lib")
    copied = false

    Dir.glob(File.join(lib_dir, "libcurl-impersonate*")).each do |src|
      filename = File.basename(src)
      # Only copy shared libraries, skip .a and .la files
      next if filename.end_with?(".a", ".la")
      dest = File.join(ext_path, filename)
      FileUtils.cp(src, dest, verbose: true)
      copied = true
    end

    abort("No shared libraries found in #{lib_dir}. Build may have failed.") unless copied
    puts "Shared libraries copied to #{ext_path}:"
    Dir.glob("ext/libcurl*").each { |f| puts "  #{f}" }
  end

  desc "Build gem for a specific arch_os target (builds from source)"
  task :build, [:arch_os] do |t, args|
    abort("Please provide an arch_os target (e.g., x86_64-linux)") unless args[:arch_os]

    arch_os = args[:arch_os]

    # Build from source
    Rake::Task["ethon_impersonate:build_from_source"].invoke(arch_os)
    Rake::Task["ethon_impersonate:build_from_source"].reenable

    # Package into gem
    gemspec_path = Dir.glob("*.gemspec").first
    abort("Gemspec file not found!") unless gemspec_path

    gemspec = Bundler.load_gemspec(gemspec_path)
    target_gem_platforms = EthonImpersonate::Impersonate::Settings::GEM_PLATFORMS_MAP[arch_os] || [arch_os]
    tmp_dir = "tmp/gemspecs"
    FileUtils.mkdir_p(tmp_dir)

    puts "Building gem(s) for #{arch_os}..."

    target_gem_platforms.each do |target_gem_platform|
      temp_gemspec = gemspec.dup
      temp_gemspec.platform = target_gem_platform
      temp_gemspec.files += Dir.glob("ext/**/*")

      temp_gemspec_path = File.join(tmp_dir, "#{File.basename(gemspec_path, ".gemspec")}.#{target_gem_platform}.gemspec")
      File.write(temp_gemspec_path, temp_gemspec.to_ruby)

      sh("gem build #{temp_gemspec_path} ")
      puts "Gem built successfully: #{target_gem_platform}"
    end
  end

  desc "Build universal ruby platform gem"
  task :build_universal do
    gemspec_path = Dir.glob("*.gemspec").first
    abort("Gemspec file not found!") unless gemspec_path

    puts "Building universal (ruby platform) gem..."
    system("gem build #{gemspec_path}") || abort("Universal gem build failed!")
    puts "Universal gem built successfully!"
  end

  desc "Publish universal ruby platform gem"
  task :publish_universal => :build_universal do
    version = EthonImpersonate::VERSION
    gem_filename = "ethon-impersonate-#{version}.gem"
    abort("Universal gem file not found: #{gem_filename}") unless File.exist?(gem_filename)

    puts "Tagging release"
    system "git tag -a v#{EthonImpersonate::VERSION} -m 'Tagging #{EthonImpersonate::VERSION}'"
    system "git push --tags"

    puts "Pushing #{gem_filename} to RubyGems..."
    system("gem push #{gem_filename}") || abort("Universal gem push failed!")
    puts "Universal gem pushed successfully!"
  end

  desc "Install the gem for the current platform after building all platform-specific gems"
  task :install do
    Rake::Task["ethon_impersonate:build_all"].invoke
    Rake::Task["ethon_impersonate:build_all"].reenable

    version = EthonImpersonate::VERSION
    platform = Gem::Platform.local.to_s

    gem_filename = "ethon-impersonate-#{version}-#{platform}.gem"

    unless File.exist?(gem_filename)
      abort("Gem file not found: #{gem_filename}")
    end

    puts "Installing #{gem_filename}..."
    system("gem install ./#{gem_filename}") || abort("gem install failed")
    puts "Installed ethon-impersonate #{version} for platform #{platform}"
  end

  desc "Publish gem for a specific arch_os target"
  task :publish, [:arch_os] => [:build] do |t, args|
    abort("Please provide an arch_os target (e.g., x86_64-linux)") unless args[:arch_os]

    arch_os = args[:arch_os]
    version = EthonImpersonate::VERSION

    target_gem_platforms = EthonImpersonate::Impersonate::Settings::GEM_PLATFORMS_MAP[arch_os] || [arch_os]

    target_gem_platforms.each do |target_gem_platform|
      gem_filename = "ethon-impersonate-#{version}-#{target_gem_platform}.gem"
      abort("Gem file not found: #{gem_filename}") unless File.exist?(gem_filename)

      puts "Pushing #{gem_filename} to RubyGems..."
      system("gem push #{gem_filename}") || abort("Gem push failed!")
    end
  end

  desc "Build all platform-specific gems (and universal)"
  task :build_all => :build_universal do
    targets = EthonImpersonate::Impersonate::Settings::LIB_PLATFORM_RELEASE_MAP.keys

    targets.each do |arch_os|
      puts "\n=== Building for #{arch_os} ==="
      Rake::Task["ethon_impersonate:build"].invoke(arch_os)
      Rake::Task["ethon_impersonate:build"].reenable
    end

    puts "All gems (universal + platform-specific) built!"
  end

  desc "Publish all gems (universal + platform-specific) to RubyGems"
  task :publish_all => :build_all do
    targets = EthonImpersonate::Impersonate::Settings::LIB_PLATFORM_RELEASE_MAP.keys

    targets.each do |arch_os|
      puts "\n=== Publishing for #{arch_os} ==="
      Rake::Task["ethon_impersonate:publish"].invoke(arch_os)
      Rake::Task["ethon_impersonate:publish"].reenable
    end

    puts "All gems (universal + platform-specific) pushed to RubyGems!"
  end

  desc "Clean up build, downloaded, and extracted files"
  task :clean do
    [
      Dir.glob("ext/libcurl*"),
      Dir.glob("tmp/*"),
      Dir.glob("ethon-impersonate-*.gem"),
    ].flatten.each { |path| FileUtils.rm_rf(path) }

    puts "Temporary files cleaned up."
  end
end

task default: :spec
