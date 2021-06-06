module Autoclockify
  class HookNotDefinedError < Exception
    def initialize(hook_name, available_hook_methods)
      hook_method_names = available_hook_methods
        .map { |name| /^on_(.*)/.match(name)[1] }
        .sort
        .join(',')

      super("No handler for Git hook type: #{hook_name}. Available: #{hook_method_names}")
    end
  end
end
