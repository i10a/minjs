module Minjs
  module ECMA262
    class Base
      def to_js(options = {})
        self.class.to_s + "??"
      end

      def to_s
        to_js({})
      end

      def concat(options, *args)
        prev = nil
        j = []
        args.flatten.each do|x|
          sep = ''
          nl = ''
          if x.kind_of? Base
            js = x.to_js(options);
          else
            js = x.to_s
          end
          if prev
            if prev.match(/[\w\$]\z/) and js.match(/^[\w\$]/)
              sep = ' '
            elsif prev.match(/;\z/) and js == "}"
              prev.sub!(/;\z/, "")
            elsif prev.match(/;\z/) and js == ";" and !options[:for_args]
              prev.sub!(/;\z/, "")
            elsif prev.match(/[\-]\z/) and js.match(/^\-/)
              sep = ' '
            elsif prev.match(/[\+]\z/) and js.match(/^\+/)
              sep = ' '
            end
          end
          #for debug
          if false and js.match(/;\z/) and !options[:for_args]
            nl = "\n"
          end
          js = "#{sep}#{js}#{nl}";
          j.push(js)
          prev = js
        end
        j.join("")
      end
    end

    class Prog < Base
      attr_reader :source_elements
      attr_reader :context

      def initialize(context, source_elements)
        @source_elements = source_elements
        @context = context
      end

      def traverse(parent, &block)
        @source_elements.each do |s|
          s.traverse(self, &block)
        end
        yield self, parent
      end

      def to_js(options = {})
        tt = ''
        vars = @context.var_env.record.binding.find_all {|k, v|
          v and v[:_parameter_list].nil? and !v[:value].kind_of?(StFunc)
        }.collect{|x|x[0]}

        tt = concat(options, tt, @source_elements)
      end

      def grouping
        sl = @source_elements
        i = 0
        while i < sl.length
          st = sl[i]
          i0 = i
          prev = nil
          t = nil
          while st and st.to_exp?
            if prev and prev.to_exp?
              t = ECMA262::ExpComma.new(t, st.to_exp({}))
            elsif prev.nil?
              t = st.to_exp({})
            else
              break
            end
            prev = st
            i += 1
            st = sl[i]
          end
          if i0 != i and i - i0 >= 2
            sl[i0...i] = StExp.new(t)
            i = (i - i0 + 1)
          else
            i += 1
          end
        end
      end

      def replace(from, to)
        idx = @source_elements.index(from)
        if idx
          @source_elements[idx] = to
        end
      end

      def remove(st)
        @source_elements.delete(st)
      end

      def each(&block)
        @source_elements.each(&block)
      end

      def [](i)
        @source_elements[i]
      end

      def index(st)
        @source_elements.index(st)
      end

    end
  end
end

