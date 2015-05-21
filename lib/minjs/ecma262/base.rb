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
            if prev.match(/[\w\$]\z/) and js.match(/\A[\w\$]/)
              sep = ' '
            end
            #;; means empty statement that must not be deleted
            if prev.match(/;;\Z/)
              prev.sub!(/;;\Z/, ";")
            elsif prev.match(/;\Z/) and js == "}"
              prev.sub!(/;\Z/, "")
            elsif prev.match(/;\Z/) and js == ";" and !options[:for_args]
              prev.sub!(/;\Z/, "")
            elsif prev.match(/[\-]\Z/) and js.match(/^\-/)
              sep = ' '
            elsif prev.match(/[\+]\Z/) and js.match(/^\+/)
              sep = ' '
            end
          end
          #for debug
          unless options[:no_debug]
            if (@logger and @logger.debug?) || options[:debug]
              if js.match(/;\z/) and !options[:for_args]
                nl = "\n"
              end
              if js.match(/}\z/) and !options[:for_args]
                nl = "\n"
              end
            end
          end
          js = "#{sep}#{js}#{nl}";
          j.push(js)
          prev = js
        end
        j.join("")
      end

      def replace(from, to)
        puts "warning: #{self.class}: replace not implement"
      end

      def deep_dup
        puts "warning: #{self.class}: deep_dup not implement"
      end

      def ==(obj)
        puts "warning: #{self.class}: == not implement"
        raise "warning: #{self.class}: == not implement"
      end
    end

    class StatementList < Base
      attr_reader :statement_list

      def initialize(statement_list)
        @statement_list = statement_list #array
      end

      def grouping
        remove_empty_statement
        new_sl = []
        sl = []
        g = []
        @statement_list.each do |st|
          if st.to_exp?
            g.push(st)
          else
            if g.length > 0
              sl.push(g)
            end
            sl.push([st])
            g = []
          end
        end
        if g.length > 0
          sl.push(g)
        end

        sl.each do |g|
          if g.length == 1
            new_sl.push(g[0])
          else
            i = 1
            t = ExpParen.new(g[0].to_exp)
            while i < g.length
              t = ExpComma.new(t, ExpParen.new(g[i].to_exp))
              i += 1
            end
            new_sl.push(StExp.new(t))
          end
        end

        if idx = new_sl.index{|x| x.class == StReturn}
          while idx < new_sl.length - 1
            new_sl.pop
          end
        end

        if self.kind_of? SourceElements
          if new_sl[-1].kind_of? StReturn and new_sl[-1].exp.nil?
            new_sl.pop
          end
        end

        if new_sl[-1].kind_of? StReturn and new_sl[-2].kind_of? StExp
          if new_sl[-1].exp
            new_sl[-2] = StReturn.new(ExpComma.new(new_sl[-2].exp, new_sl[-1].exp))
            new_sl.pop
          end
        end
        @statement_list = new_sl
      end

      def deep_dup
        self.class.new(@statement_list.collect{|s| s.deep_dup})
      end

      def replace(from, to)
        idx = @statement_list.index(from)
        if idx
          @statement_list[idx] = to
        end
      end

      def remove(st)
        @statement_list.delete(st)
      end

      def remove_empty_statement
        @statement_list.reject!{|x|
          x.class == StEmpty
        }
      end

      def traverse(parent, &block)
        @statement_list.each do|st|
          st.traverse(self, &block)
        end
        yield self, parent
      end

      def ==(obj)
        @statement_list == obj.statement_list
      end

      def to_js(options = {})
        concat options, @statement_list
      end

      def length
        @statement_list.length
      end

      def to_exp?
        @statement_list.each do |s|
          return false if s.to_exp? == false
        end
        return true
      end

      def to_exp(options = {})
        return nil if to_exp? == false
        t = @statement_list[0].to_exp(options)
        return t.to_exp(options) if @statement_list.length <= 1
        i = 1
        while(i < @statement_list.length)
          t = ExpComma.new(t, @statement_list[i])
          i += 1
        end
        t
      end

      def each(&block)
        @statement_list.each(&block)
      end

      def [](i)
        @statement_list[i]
      end

      def []=(i, s)
        @statement_list[i] = s
      end

      def index(st)
        @statement_list.index(st)
      end
    end

    class SourceElements < StatementList
      #
      # source_elements: [statement, statement, ...]
      #
      def initialize(source_elements)
        @statement_list = source_elements
      end

      def source_elements
        @statement_list
      end

      def source_elements=(source_elements)
        @statement_list = source_elements
      end

      def ==(obj)
        statement_list == obj.statement_list
      end
    end

    class Prog < Base
      attr_reader :source_elements
      attr_reader :context

      def initialize(context, source_elements)
        @source_elements = source_elements
        @context = context
      end

      def deep_dup
        self.class.new(context, source_elements.deep_dup)
      end
      def traverse(parent, &block)
        @source_elements.traverse(self, &block)
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and self.source_elements == obj.source_elements
      end

      def to_js(options = {})
        concat options, @source_elements
      end
    end
  end
end

