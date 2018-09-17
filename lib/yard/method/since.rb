require "yard/method/since/version"
require 'open3'
require 'rugged'

module Yard
  module Method
    module Since
      def generate_databases(dir, rc: false, stable: false, from: nil, to: nil)
        d = '.' if dir.nil?
        Dir.chdir(d) do
          versions(from, to, d).each do |version|
            next if !rc && /-rc1\z/i.match(version)
            next if !stable && /-stable\z/i.match(version)

            puts "generating #{version}..."
            Rugged::Repository.new(d).checkout(version,
                                               strategy: :force)
            system('yard', 'doc', '--no-output')
            system('mv', '.yardoc', yardoc_path(version))
          end
        end
      ensure
        # TODO: back to current.
        Rugged::Repository.new(d).checkout('master',
                                           strategy: :force)
      end

      def compare_databases(dir, from: nil, to: nil, github: nil)
        d = '.' if dir.nil?
        res = []
        regexp = /\A(Added|Modified|Removed) objects:/

        Dir.chdir(d) do
          versions(from, to, d).sort.each_cons(2) do |v1, v2|
            puts "comparing #{v1} and #{v2}..."
            out, st = Open3.capture2('yard', 'diff',
                                  yardoc_path(v1), yardoc_path(v2))
            out.each_line.reject {|s| s == "\n" }.slice_before {|s1, s2|
              regexp.match(s1)
            }.each { |t, *methods|
              t = t.slice(regexp, 1)
              methods.each { |s|
                m = s.slice(/\A\s*([^\s]+)/, 1)
                a = [nil, m, v2, t.downcase, '', nil]
                if github
                  url = github_compare_url(github, v1, v2)
                  a[4] = "[compare url](#{url})"
                end
                res << a
              }
            }
          end
        end

        puts <<EOS
| method | version | action | detail |
|--------|---------|--------|--------|
EOS

          puts res.sort { |a, b|
            # Compare version if method is the same.
            a[1] == b[1] ? a[2] <=> b[2] : a[1] <=> b[1]
          }.map {|a| a.join('|')}.join("\n")
      end

      def yardoc_path(v, d = '.')
        File.join(d, ".yardoc.#{v}")
      end

      # only github
      def github_compare_url(github, v1, v2)
        return File.join('https://github.com', github,
                         'compare', "#{v1}...#{v2}")
      end

      def versions(from = nil, to = nil, d = '.')
        repo = Rugged::Repository.new(d)
        from_ver = Gem::Version.new(from) if from
        to_ver = Gem::Version.new(to) if to
        return repo.tags.map(&:name).select { |v|
          case
          when from_ver && Gem::Version.new(v) < from_ver
            false
          when to_ver && Gem::Version.new(v) > to_ver
            false
          else
            true
          end
        }.sort
      end
    end
  end
end
