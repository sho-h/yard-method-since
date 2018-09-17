require "yard/method/since/version"
require 'rugged'

module Yard
  module Method
    module Since
      def generate_databases(dir, rc: false, stable: false)
        versions = []
        repo = Rugged::Repository.new(dir)
        Dir.chdir(dir) do
          repo.tags.map(&:name).sort.each do |version|
            next if !rc && /-rc1\z/i.match(version)
            next if !stable && /-stable\z/i.match(version)

            puts "generating #{version}..."
            repo.checkout(version, strategy: :force)
            system('yard', 'doc', '--no-output')
            system('mv', '.yardoc', yardoc_path(version))
            versions << version
          end
          return versions
        end
      ensure
        # TODO: back to current.
        repo.checkout('master', strategy: :force)
      end
      module_function :generate_databases

      def yardoc_path(v, d = '.')
        File.join(d, ".yardoc.#{v}")
      end
      module_function :yardoc_path
    end
  end
end
