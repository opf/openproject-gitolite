module OpenProject::Gitolite
  module Commands
    module Base
      extend self

      # Wrapper to Open3.capture.
      #
      def capture(args = [], opts = {})
        cmd = args.shift
        OpenProject::Gitolite::Utils::Exec.capture(cmd, args, opts)
      end


      # Wrapper to Open3.capture.
      #
      def execute(args = [], opts = {})
        cmd = args.shift
        OpenProject::Gitolite::Utils::Exec.execute(cmd, args, opts)
      end


      private


        def logger
          OpenProject::Gitolite.logger
        end

    end
  end
end
