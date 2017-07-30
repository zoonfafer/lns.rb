==========================================
 ``lns`` ("`lns`" is short for ``ln -s``)
==========================================

Introduction
------------

A script to maintain a set of symbolic links in the specified directories.

Given a source directory and a list of relative path names (relative to the
source directory) and a destination directory, the program should generate a
symbolic link for each of the path in the list at the destination directory
pointing to the path of the same name at the source directory.


Motivation
----------

I want to have an easy way to work with the many plugins installed with
`vim-pathogen`__ in ``~/.vim/bundle``.

But then I realized that it is useful in many other cases, like for Emacs's
plugins (in ``~/.emacs.d``)!

__ https://github.com/tpope/vim-pathogen


Installation
------------

Just put ``lns`` in your ``PATH``.


Usage
-----

After editing your ``~/.lnsconfig.rb``, just run::

    $ lns

to refresh the symlinks!


Configuration
-------------

Start ``lns`` with the ``--init`` flag to create and modify from a sample
configuration file::

  $ lns --init
  $ $EDITOR ~/.lnsconfig.rb


Todos
-----

I haven't really tested this script extensively, so the TODO list probably goes
like (in no particular order):-

- write a test suite,
- change to a better name,
- more documentation,
- implement ``--dry-run``.


Licence
-------

.. GNU General Public License version 3.  Copyright © 2011 ``lns`` authors.  All Rights Reserved.


GNU General Public License version 3.
Copyright (c) 2011-2017 ``lns`` authors.  All Rights Reserved.

Please see the ``COPYING`` file provided with the source distribution for full 
details.


Authors
-------

- Jeffrey Lau <github@NOSPAMjlau.tk>

