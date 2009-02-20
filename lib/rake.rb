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

require 'rake/name_space'
require 'rake/task_manager'
require 'rake/application'

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
end # module Rake

# ###########################################################################
# Task Definition Functions ...

# Declare a basic task.
#
# Example:
#   task :clobber => [:clean] do
#     rm_rf "html"
#   end
#
def task(*args, &block)
  Rake::Task.define_task(*args, &block)
end


# Declare a file task.
#
# Example:
#   file "config.cfg" => ["config.template"] do
#     open("config.cfg", "w") do |outfile|
#       open("config.template") do |infile|
#         while line = infile.gets
#           outfile.puts line
#         end
#       end
#     end
#  end
#
def file(*args, &block)
  Rake::FileTask.define_task(*args, &block)
end

# Declare a file creation task.
# (Mainly used for the directory command).
def file_create(args, &block)
  Rake::FileCreationTask.define_task(args, &block)
end

# Declare a set of files tasks to create the given directories on demand.
#
# Example:
#   directory "testdata/doc"
#
def directory(dir)
  Rake.each_dir_parent(dir) do |d|
    file_create d do |t|
      mkdir_p t.name if ! File.exist?(t.name)
    end
  end
end

# Declare a task that performs its prerequisites in parallel. Multitasks does
# *not* guarantee that its prerequisites will execute in any given order
# (which is obvious when you think about it)
#
# Example:
#   multitask :deploy => [:deploy_gem, :deploy_rdoc]
#
def multitask(args, &block)
  Rake::MultiTask.define_task(args, &block)
end

# Create a new rake namespace and use it for evaluating the given block.
# Returns a NameSpace object that can be used to lookup tasks defined in the
# namespace.
#
# E.g.
#
#   ns = namespace "nested" do
#     task :run
#   end
#   task_run = ns[:run] # find :run in the given namespace.
#
def namespace(name=nil, &block)
  Rake.application.in_namespace(name, &block)
end

# Declare a rule for auto-tasks.
#
# Example:
#  rule '.o' => '.c' do |t|
#    sh %{cc -o #{t.name} #{t.source}}
#  end
#
def rule(*args, &block)
  Rake::Task.create_rule(*args, &block)
end

# Describe the next rake task.
#
# Example:
#   desc "Run the Unit Tests"
#   task :test => [:build]
#     runtests
#   end
#
def desc(description)
  Rake.application.last_description = description
end

# Import the partial Rakefiles +fn+.  Imported files are loaded _after_ the
# current file is completely loaded.  This allows the import statement to
# appear anywhere in the importing file, and yet allowing the imported files
# to depend on objects defined in the importing file.
#
# A common use of the import statement is to include files containing
# dependency declarations.
#
# See also the --rakelibdir command line option.
#
# Example:
#   import ".depend", "my_rules"
#
def import(*fns)
  fns.each do |fn|
    Rake.application.add_import(fn)
  end
end

# ###########################################################################
# Include the FileUtils file manipulation functions in the top level module,
# but mark them private so that they don't unintentionally define methods on
# other objects.

include RakeFileUtils
private(*FileUtils.instance_methods(false))
private(*RakeFileUtils.instance_methods(false))

# Alias FileList to be available at the top level.
FileList = Rake::FileList

# ###########################################################################
module Rake

  # Default Rakefile loader used by +import+.
  class DefaultLoader
    def load(fn)
      Kernel.load(File.expand_path(fn))
    end
  end

  # EarlyTime is a fake timestamp that occurs _before_ any other time value.
  class EarlyTime
    include Comparable
    include Singleton

    def <=>(other)
      -1
    end

    def to_s
      "<EARLY TIME>"
    end
  end

  EARLY = EarlyTime.instance
end # module Rake

class Module
  # Rename the original handler to make it available.
  alias :rake_original_const_missing :const_missing

  # Check for deprecated uses of top level (i.e. in Object) uses of
  # Rake class names.  If someone tries to reference the constant
  # name, display a warning and return the proper object.  Using the
  # --classic-namespace command line option will define these
  # constants in Object and avoid this handler.
  def const_missing(const_name)
    case const_name
    when :Task
      Rake.application.const_warning(const_name)
      Rake::Task
    when :FileTask
      Rake.application.const_warning(const_name)
      Rake::FileTask
    when :FileCreationTask
      Rake.application.const_warning(const_name)
      Rake::FileCreationTask
    when :RakeApp
      Rake.application.const_warning(const_name)
      Rake::Application
    else
      rake_original_const_missing(const_name)
    end
  end
end
