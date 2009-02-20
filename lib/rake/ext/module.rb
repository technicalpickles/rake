######################################################################
# Rake extensions to Module.
#
class Module
  # Check for an existing method in the current class before extending.  IF
  # the method already exists, then a warning is printed and the extension is
  # not added.  Otherwise the block is yielded and any definitions in the
  # block will take effect.
  #
  # Usage:
  #
  #   class String
  #     rake_extension("xyz") do
  #       def xyz
  #         ...
  #       end
  #     end
  #   end
  #
  def rake_extension(method)
    if instance_methods.include?(method.to_s) || instance_methods.include?(method.to_sym)
      $stderr.puts "WARNING: Possible conflict with Rake extension: #{self}##{method} already exists"
    else
      yield
    end
  end
end # module Module
