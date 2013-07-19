require 'English'
require 'rubygems/command'
require 'rubygems/version_option'

class Gem::Commands::ContentsCommand < Gem::Command

  include Gem::VersionOption

  def initialize
    super 'contents', 'Display the contents of the installed gems',
          :specdirs => [], :lib_only => false, :prefix => true

    add_version_option

    add_option(      '--all',
               "Contents for all gems") do |all, options|
      options[:all] = all
    end

    add_option('-s', '--spec-dir a,b,c', Array,
               "Search for gems under specific paths") do |spec_dirs, options|
      options[:specdirs] = spec_dirs
    end

    add_option('-l', '--[no-]lib-only',
               "Only return files in the Gem's lib_dirs") do |lib_only, options|
      options[:lib_only] = lib_only
    end

    add_option(      '--[no-]prefix',
               "Don't include installed path prefix") do |prefix, options|
      options[:prefix] = prefix
    end

    @path_kind = nil
    @spec_dirs = nil
    @version   = nil
  end

  def arguments # :nodoc:
    "GEMNAME       name of gem to list contents for"
  end

  def defaults_str # :nodoc:
    "--no-lib-only --prefix"
  end

  def usage # :nodoc:
    "#{program_name} GEMNAME [GEMNAME ...]"
  end

  def execute
    @version   = options[:version] || Gem::Requirement.default
    @spec_dirs = specification_directories
    @path_kind = path_description @spec_dirs

    names = gem_names

    names.each do |name|
      found = gem_contents name

      terminate_interaction 1 unless found or names.length > 1
    end
  end

  def files_in spec
    if spec.default_gem? then
      files = spec.files.sort.map do |file|
        case file
        when /\A#{spec.bindir}\//
          [Gem::ConfigMap[:bindir], $POSTMATCH]
        when /\.so\z/
          [Gem::ConfigMap[:archdir], file]
        else
          [Gem::ConfigMap[:rubylibdir], file]
        end
      end
    else
      gem_path  = spec.full_gem_path
      extra     = "/{#{spec.require_paths.join ','}}" if options[:lib_only]
      glob      = "#{gem_path}#{extra}/**/*"
      prefix_re = /#{Regexp.escape(gem_path)}\//
      files     = Dir[glob].map do |file|
        [gem_path, file.sub(prefix_re, "")]
      end
    end

  end

  def gem_contents name
    spec = spec_for name

    return unless spec

    files = files_in spec

    files.sort.each do |prefix, basename|
      absolute_path = File.join(prefix, basename)
      next if File.directory? absolute_path

      if options[:prefix]
        say absolute_path
      else
        say basename
      end
    end

    true
  end

  def gem_names # :nodoc:
    if options[:all] then
      Gem::Specification.map(&:name)
    else
      get_all_gem_names
    end
  end

  def path_description spec_dirs # :nodoc:
    if spec_dirs.empty? then
      spec_dirs = Gem::Specification.dirs
      "default gem paths"
    else
      "specified path"
    end
  end

  def spec_for name
    spec = Gem::Specification.find_all_by_name(name, @version).last

    return spec if spec

    say "Unable to find gem '#{name}' in #{@path_kind}"

    if Gem.configuration.verbose then
      say "\nDirectories searched:"
      @spec_dirs.sort.each { |dir| say dir }
    end

    return nil
  end

  def specification_directories # :nodoc:
    options[:specdirs].map do |i|
      [i, File.join(i, "specifications")]
    end.flatten
  end

end

