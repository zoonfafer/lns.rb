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
# Turned into a Ruby file with hopes that it can be run with Vim's Ruby
# interface.
#
# == Extension
# - config file per app, or one global config with per-app sections
# - Let config file be a DSL?
#
# Jeffrey Lau
# 2011-08-19

# bash compatibility
#
def echo *stuff
  puts stuff.join ' '
end

$dir_stack = []
def pushd path
  if Dir.chdir path
    $dir_stack << path
  end
end

def popd
  Dir.chdir $dir_stack.pop
end

$vim_mode = false
# TODO: move all these constants into the config file
# TODO: vim mode -- read config from .vimrc
# TODO: normal ruby mode --- read from .lnsconfig or something (INI?)

if $vim_mode
  # do something... read from Vim's variables
else
  SRC_DIR = File.expand_path "~/opt/src/vim-bundle"
  DST_DIR = File.expand_path "~/.vim/bundle"

  # TODO: make optional
  # SRC_LN: e.g., $SRC_DIR/.yo -> $DST_DIR
  SRC_LN = ".src"

  # DST_LN: e.g., $DST_DIR/.src -> $SRC_DIR
  DST_LN = ".yo"
  # --->END TODOs
end

def dir path
  pushd path
  yield
  popd
end

# create the LNs if not exists
def create_lnln src, dst_ln, dst

  if  File.writable? src
    # echo src, 'is writable'

    ln_path="#{src}/#{dst_ln}"
    # echo "ln path is #{ln_path}"

    if File.exists? ln_path

      dir src do
        # echo 'lol'

        begin
          File.symlink dst, dst_ln
        rescue Errno::EEXIST
        end
      end

    elsif ! File.symlink? ln_path

      warn "Error:- something `#{ln_path}' exists already --- cannot create symlink with same name"
      return 2

    else
      # Oh, another symlink exists already!
      # Let's compare them to see if they reference the same thing.

      resolved_dst_dir = dir dst do Dir.pwd end
      # echo "resolving #{dst}"
      # echo resolved_dst_dir

      resolved_ln_path = dir ln_path do Dir.pwd end
      # echo "resolving #{ln_path}"
      # echo resolved_ln_path

      if resolved_dst_dir != resolved_ln_path
        warn "Error:- a different symlink to `#{resolved_ln_path}' exists already --- cannot decide what to do!"
        return 2
      end
    end
  end
end

create_lnln SRC_DIR, DST_LN, DST_DIR
create_lnln DST_DIR, SRC_LN, SRC_DIR || exit(2)

# read list from a config file
CONFIG_FILE = File.expand_path "~/.lns"
if ! File.readable? CONFIG_FILE
  warn "Error:- cannot read config file from #{CONFIG_FILE}"
  warn "     :  It should be a list of path names separated by newlines."
  exit 2
else
  LIST = (File.read File.expand_path CONFIG_FILE).split(/\n/)
end

# CREATION
#
for i in LIST
  # echo "---> #{i} "
  src_path = "#{SRC_DIR}/#{i}"

  # bail if source doesn't exist
  if ! File.readable? src_path
    warn "Error: source directory `#{src_path}' ain't readable"
    next
  end

  # echo "is", "#{DST_DIR}/#{i} readable?"
  if ! File.readable? "#{DST_DIR}/#{i}"
    # echo 'no!'
    dir DST_DIR do
      # ln -s ${src_path} .
      #
      # prefer the extra indirection
      begin
        # echo 'creating sln ', "#{SRC_LN}/#{i}", i
        File.symlink "#{SRC_LN}/#{i}", i
      rescue Errno::EEXIST
      end
    end
    # else
    # warn "Error: destination exists already!!!1"
    # exit 2
  else
    # echo 'yes...'
  end
end

# DESTRUCTION
# 
# Remove all symlinks if they can be found in $SRC_DIR but are not in the 
# LIST.

for i in Dir["#{DST_DIR}/*"]
  last_bit = File.basename i
  # echo "===> #{last_bit}"

  possible = "#{SRC_DIR}/#{last_bit}"
  # echo 'possible', possible
  if File.readable? possible
    # echo "hey you!"
    if ! LIST.include? last_bit
      # echo "YES YOU!!!1"
      File.unlink i
    end
  end
end

exit 0

__END__
