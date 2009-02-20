#!/usr/bin/env ruby

#--

# Copyright 2003, 2004, 2005, 2006, 2007, 2008 by Jim Weirich (jim@weirichhouse.org)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#++
#
# = Rake -- Ruby Make
#
# This is the main file for the Rake application.  Normally it is referenced
# as a library via a require statement, but it can be distributed
# independently as an application.

RAKEVERSION = '0.8.3.100'

require 'rbconfig'
require 'fileutils'
require 'singleton'
require 'monitor'
require 'optparse'
require 'ostruct'

require 'rake/win32'


require 'rake/ext/module'
require 'rake/ext/string'
require 'rake/ext/file_utils'
require 'rake/ext/time'

require 'rake/task_arguments'
require 'rake/invocation_chain'
require 'rake/cloneable'

require 'rake/task'
require 'rake/file_task'
require 'rake/file_creation_task'
require 'rake/multi_task'

require 'rake/rake_file_utils'
require 'rake/file_list'

require 'rake/default_loader'
require 'rake/early_time'

require 'rake/name_space'
require 'rake/task_manager'
require 'rake/application'

require 'rake/dsl'

module Rake

  # Errors -----------------------------------------------------------

  # Error indicating an ill-formed task declaration.
  class TaskArgumentError < ArgumentError
  end

  # Error indicating a recursion overflow error in task selection.
  class RuleRecursionOverflowError < StandardError
    def initialize(*args)
      super
      @targets = []
    end

    def add_target(target)
      @targets << target
    end

    def message
      super + ": [" + @targets.reverse.join(' => ') + "]"
    end
  end

  # --------------------------------------------------------------------------
  # Rake module singleton methods.
  #
  class << self
    # Current Rake Application
    def application
      @application ||= Rake::Application.new
    end

    # Set the current Rake application object.
    def application=(app)
      @application = app
    end

    # Return the original directory where the Rake application was started.
    def original_dir
      application.original_dir
    end

    # Yield each file or directory component.
    def each_dir_parent(dir)    # :nodoc:
      old_length = nil
      while dir != '.' && dir.length != old_length
        yield(dir)
        old_length = dir.length
        dir = File.dirname(dir)
      end
    end
  end

  EMPTY_TASK_ARGS = TaskArguments.new([], [])
  EARLY = EarlyTime.instance
end # module Rake


# ###########################################################################
# Include the FileUtils file manipulation functions in the top level module,
# but mark them private so that they don't unintentionally define methods on
# other objects.

include RakeFileUtils
private(*FileUtils.instance_methods(false))
private(*RakeFileUtils.instance_methods(false))

# Alias FileList to be available at the top level.
FileList = Rake::FileList
