#!/usr/bin/env ruby

# A script to maintain a set of symbolic links in the specified directory.
#
# Given a source directory and a list of relative path names (relative to the
# source directory) and a destination directory, the program should generate a
# symbolic link for each of the path in the list at the destination directory
# pointing to the path of the same name at the source directory.
#
# == Motivation
# I want to have an easy way to work with the many plugins installed with
# vim-pathogen.
#
# But then I realized that it is useful in many other cases, like for Emacs's
# plugins!
#
# == Configuration
# The config file is a Ruby DSL file.  See __END__ for an example.
#
# Jeffrey Lau
# 2011-12-28

require 'pp'
require 'optparse'
require 'ostruct'

$N = File::basename $0
$VERSION = 0.02

$default_config_file = '~/.lnsconfig.rb'

module DirUtil
  #
  def self.extended base
    class << base
      attr_accessor :dir_stack
      @dir_stack = []
    end
  end

  def ds
    class << self; @dir_stack; end
  end

  def pushd path
    if Dir.chdir path
      # @dir_stack << path
      ds << path
    end
  end

  def popd
    # Dir.chdir @dir_stack.pop
    Dir.chdir ds.pop
  end

  # util
  def dir path
    pushd path
    yield
    popd
  end
end

class Lns

  extend DirUtil

  # create the LNs if not exists
  #
  def self.create_lnln src, dst_ln, dst

    if  File.writable? src

      ln_path="#{src}/#{dst_ln}"

      if ! File.exists? ln_path

        dir src do
          begin
            File.symlink dst, dst_ln
          rescue Errno::EEXIST
          end
        end

      else

        if ! File.symlink? ln_path
          if $opts.verbose
            warn ""
            warn " [warning] something at:-"
            warn " [w      ]     #{ln_path}"
            warn " [w      ] already exists --- cannot create symlink with same name"
          end
          return 2 # TODO

        else
          # Oh, another symlink exists already!
          # Let's compare them to see if they reference the same thing.

          resolved_dst_dir = dir dst do Dir.pwd end
          resolved_ln_path = dir ln_path do Dir.pwd end

          if resolved_dst_dir != resolved_ln_path
            # unless $opts.quiet
            warn ""
            warn "Warning:- a different symlink to\n    #{resolved_ln_path}"
            warn "       :  exists already --- cannot decide what to do!"
            # end
            return 2 # TODO
          end
        end
      end
    end
  end

  # bail if config file is not readable
  #
  def self.read_config_and_do_it config_file_path

    # read list from a config file
    _CONFIG_FILE = File.expand_path config_file_path

    if File.readable?(_CONFIG_FILE) && $opts.init && $opts.verbose
      puts
      puts " [info] config file at:-"
      puts " [i   ]     #{_CONFIG_FILE}"
      puts " [i   ] already exists.  Not going to write a new one."
    end

    # If config file doesn't exist, and the user hasn't asked to create it,
    # bail.
    if ! File.exists? _CONFIG_FILE
      if $opts.init
        File.open(_CONFIG_FILE, 'w') do |f|
          f.write DATA.read
        end
      else
        warn ""
        warn "Error:- config file `#{_CONFIG_FILE}' doesn't exist"
        warn "     :  Please create the file."
        warn "     :  You can use the `--init' flag to create a sample and modify as"
        warn "     :  necessary."
        exit 2
      end
    elsif ! File.readable? _CONFIG_FILE
      warn ""
      warn "Error:- cannot read config file from `#{_CONFIG_FILE}'"
      warn "     :  Please make it readable : chmod +r \"#{_CONFIG_FILE}\""
      exit 2
    end

    self.do_it _CONFIG_FILE
  end

  # Read from the config file and do stuff.
  #
  def self.do_it _CONFIG_FILE

    apps = Lns::DSL::LinksConfig.new.
      instance_eval(File.read(_CONFIG_FILE), _CONFIG_FILE).to_h

    apps.each_pair do |app, app_config|

      _LIST = app_config[:list]

      _SRC_DIR = File.expand_path app_config[:src]
      _DST_DIR = File.expand_path app_config[:dst]
      _DST_LN  = app_config[:s2d]  # whatever this variable is called is not important
      _SRC_LN  = app_config[:d2s]  # whatever this variable is called is not important

      if ! File.directory?(_SRC_DIR) || ! File.readable?(_SRC_DIR)
        warn ""
        warn "Error:- source directory at:-\n    #{_SRC_DIR}"
        warn "     :  ain't a readable directory"
        warn "Aborting. (was processing app `#{app}'.)"
        exit 2
      end

      if ! File.directory?(_DST_DIR) || ! File.readable?(_DST_DIR)
        warn ""
        warn "Error:- destination directory at:-\n    #{_DST_DIR}"
        warn "     :  ain't a readable directory"
        warn "Aborting. (was processing app `#{app}'.)"
        exit 2
      end

      self.create_lnln _SRC_DIR, _DST_LN, _DST_DIR
      self.create_lnln _DST_DIR, _SRC_LN, _SRC_DIR

      self.create_symlinks  _LIST, _DST_DIR, _SRC_DIR, _SRC_LN
      self.destroy_symlinks _LIST, _DST_DIR, _SRC_DIR
    end
  end

  # Create and destroy symlinks according to the +_LIST+.
  #
  def self.create_symlinks _LIST, _DST_DIR, _SRC_DIR, _SRC_LN=nil

    # CREATION
    #
    _LIST.each do |i|
      src_path = "#{_SRC_DIR}/#{i}"

      # bail if source doesn't exist
      if ! File.readable? src_path
        # XXX: warning?
        if $opts.verbose
          warn ""
          warn " [warning] source directory at:-"
          warn " [w      ]     #{src_path}"
          warn " [w      ] ain't readable"
        end
        next
      end

      if ! File.readable? "#{_DST_DIR}/#{i}"
        dir _DST_DIR do
          # prefer the extra indirection if available
          begin
            dir_bit = _SRC_LN.nil? ? src_path : "#{_SRC_LN}/#{i}"
            File.symlink dir_bit, i
          rescue Errno::EEXIST
            # Ahem... Everything's under control.  Nothing to see here.  Please
            # move along!
          end
        end
      # else
      #   warn ""
      #   warn "Error: destination exists already!!!1"
      #   exit 2
      end
    end
  end

  def self.destroy_symlinks _LIST, _DST_DIR, _SRC_DIR

    # DESTRUCTION
    #
    # Remove all symlinks if they can be found in _SRC_DIR but are not in the
    # _LIST.
    #
    Dir["#{_DST_DIR}/*"].each do |i|
      last_bit = File.basename i

      maybe_src_dir = "#{_SRC_DIR}/#{last_bit}"
      if File.readable?(maybe_src_dir) && ! _LIST.include?(last_bit)
        File.unlink i
      end
    end

  end
end



module Lns::DSL

  #
  # define for a single App
  #
  class AppConfig

    MethodMap = {
      :destination => :dst,
      :dst         => :dst, # alias
      :source      => :src,
      :src         => :src, # alias
      :src2dst     => :s2d,
      :s2d         => :s2d, # alias
      :dst2src     => :d2s,
      :d2s         => :d2s, # alias
    }

    # (class << self; self; end).class_eval do
    class_eval do
      MethodMap.each_pair do |k, v|
        define_method k.to_sym do |arg|
          @stuff[v.to_sym] = arg
        end
      end
    end

    def initialize; @stuff = {}; end

    # "serialization"
    def to_h; @stuff; end

  end # class AppConfig


  #
  # define for the entire ensemble
  #
  class LinksConfig

    # initialize unique Hash map for different apps
    def initialize; @apps = {}; end

    # disabled stuff
    # TODO: may want to report on it?
    def xapp name, &blk; self; end

    # register the app and the symlink definitions
    def app name, &blk
      ac = AppConfig.new
      @apps[name] = {
        :list => ac.instance_eval(&blk)
      }

      # bail if list is not a list!
      case @apps[name][:list]
      when Array then
        @apps[name].merge! ac.to_h
      else
        warn ""
        warn "Warning:- please return an Array for the configuration of `#{name}'." # unless $opts.quiet
        @apps.delete name
      end

      self
    end

    # "serialization"
    def to_h; @apps; end

  end # class LinksConfig
end # modele Lns::DSL



#
# The option parser is OP.
#
class OP

  DEFAULTS = {
    :quiet   => false,
    :verbose => false,
    :dryrun  => false,
  }

  def self.parse args
    options = OpenStruct.new DEFAULTS

    op = OptionParser.new do |opts|
      opts.banner = "Usage: #{$N} [options]"

      opts.separator ""
      opts.separator "Specific options:"

      opts.on("--init",
        "Create the configuration file"
      ) do |v|
        options.init = v
      end

      opts.on("-v", "--[no-]verbose",
        "Run verbosely",
        "  (default:  #{DEFAULTS[:verbose]})"

      ) do |v|
        options.verbose = v
      end

      opts.on("-d", "--dry-run",
        "UNIMPLEMENTED.  Only simulate it.",
        "  (default:  #{DEFAULTS[:dryrun]})"

      ) do |d|
        options.dryrun = d
      end

      opts.separator "\nCommon options:"
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.on_tail("--version", "Show version") do
        puts $VERSION
        exit
      end

    end

    op.parse! args
    options
  end  # parse()
end # class OP

#
# int main()
#
if $0 == __FILE__
  $opts = OP.parse ARGV
  Lns.read_config_and_do_it $default_config_file
else
  puts 'r u frm irb????/'
end

exit 0

__END__
#
# This file is automatically generated with lns.rb.
# Please edit it to your needs.
#

#
# Prepending the word `app' with `x' disables the entire group.
#

# app 'vim' do
xapp 'vim' do # The app name doesn't matter, but has to be unique.

  # REQUIRED
  # Paths are expanded.
  #

  # source: where the symlinks should point to
  #
  source '~/opt/src/vim-bundle'
  # src '~/opt/src/vim-bundle' # an alias

  # destination: where the symlinks should live
  #
  destination '~/.vim/bundle'
  # dst '~/.vim/bundle' # an alias

  # OPTIONAL
  # dest to source link: e.g., $DST_DIR/.src -> $SRC_DIR
  d2s '.src'

  # OPTIONAL
  # source to dest link: e.g., $SRC_DIR/.dst -> $DST_DIR
  s2d '.dst'

  # REQUIRED
  # Must return a list.
  %w(
    AnsiEsc.vim
    bufkill.vim
    Command-T
    delimitMate
    EasyGrep
    ensime
    gundo.vim
    jslint.vim
    liftweb-vim
    lusty
    matchit.zip
    nerdcommenter
    nerdtree
    snipmate-snippets
    snipmate.vim
    syntastic
    tabular
    tagbar
    tcomment_vim
    tlib_vim
    tplugin_vim
    vim-abolish
    vim-addon-async
    vim-addon-completion
    vim-addon-json-encoding
    vim-addon-manager
    vim-addon-mw-utils
    vim-align
    vim-coffee-script
    vim-colors-solarized
    vim-conque
    vim-endwise
    vim-fugitive
    vim-fuzzyfinder
    vim-git
    vim-javascript
    vim-jst
    vim-l9
    vim-mythryl
    vim-pathogen
    vim-powerline
    vim-ragtag
    vim-repeat
    vim-scala.zfp
    vim-simplefold
    vim-snipmate
    vim-space
    vim-sparkup
    vim-surround
    vim-taglist-plus
    vim-textobj-rubyblock
    vim-textobj-user
    vim-tk.jlau.dotfiles
    vim-trailing-whitespace
    vim-unimpaired
    vim-vspec
    zencoding-vim
  )
end
