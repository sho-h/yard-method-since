require "yard/method/since/version"
require 'open3'
require 'rugged'

module Yard
  module Method
    module Since
      def generate_databases(dir, rc: false, stable: false)
        d = '.' if dir.nil?
        versions = []
        repo = Rugged::Repository.new(d)
        Dir.chdir(d) do
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
        repo = Rugged::Repository.new(d)
        repo.checkout('master', strategy: :force)
      end

      def compare_databases(dir, versions)
        d = '.' if dir.nil?
        res = []
        regexp = /\A(Added|Modified|Deleted) objects:/
        type2index = {
          'added'    => 2,
          'modified' => 3,
          'deleted'  => 4,
        }

        Dir.chdir(d) do
          versions.sort.each_cons(2) do |v1, v2|
            out, st = Open3.capture2('yard', 'diff',
                                  yardoc_path(v1), yardoc_path(v2))
            out.each_line.reject {|s| s == "\n" }.slice_before {|s1, s2|
              regexp.match(s1)
            }.each { |t, *methods|
              t = t.slice(regexp, 1)
              methods.each { |s|
                m = s.slice(/\A\s*([^\s]+)/, 1)
                a = [nil, m, '-', '-', '-', '', nil]
                index = type2index[t.downcase]
                a[index] = v2
                res << a
              }
            }
          end
        end

        puts <<EOS
| method | added | modified | deleted | detail |
|--------|-------|----------|---------|--------|
EOS

          puts res.sort { |a, b|
            a[1] <=> b[1]
          }.map {|a| a.join('|')}.join("\n")
      end

      def yardoc_path(v, d = '.')
        File.join(d, ".yardoc.#{v}")
      end
    end
  end
end
