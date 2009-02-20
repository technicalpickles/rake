module Rake
  # #########################################################################
  # Same as a regular task, but the immediate prerequisites are done in
  # parallel using Ruby threads.
  #
  class MultiTask < Task
    def invoke_prerequisites(args, invocation_chain)
      threads = @prerequisites.collect { |p|
        Thread.new(p) { |r| application[r].invoke_with_call_chain(args, invocation_chain) }
      }
      threads.each { |t| t.join }
    end
  end
end
