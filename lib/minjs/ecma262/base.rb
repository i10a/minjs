module Minjs
  module ECMA262
    #ECMA262 Elements
    class Base
      attr_accessor :parent

      # Returns a ECMAScript string containg the representation of element.
      # @param options [Hash] options for Base#concat
      # @return [String] ECMAScript string.
      def to_js(options = {})
        self.class.to_s + "??"
      end

      # concatenate some of ECMA262 elements and convert it to ECMAScript
      #
      # @param args ECMA262 element
      # @option options :debug [Boolean] if set, output is easy to read.
      #
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
            # ';;' means 'empty statement' or separator of 'for statement'
            # that must not be deleted
            if prev.match(/;;\Z/)
              prev.sub!(/;;\Z/, ";")
            elsif prev.match(/;\Z/) and js == "}"
              prev.sub!(/;\Z/, "")
            elsif prev.match(/;\Z/) and js == ";"
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
              if js.match(/;\z/)
                nl = "\n"
              end
              if js.match(/}\z/)
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

      # Replaces child (if own it) object
      #
      # @param from [Base] from
      # @param to [Base] to
      def replace(from, to)
        puts "warning: #{self.class}: replace not implement"
      end

      # duplicate object
      #
      # duplicate this object's children (if own) and itself.
      def deep_dup
        puts "warning: #{self.class}: deep_dup not implement"
      end

      # compare object
      def ==(obj)
        puts "warning: #{self.class}: == not implement"
        raise "warning: #{self.class}: == not implement"
      end

      # add / remove parenthesis if need
      def add_remove_paren(node = self)
        node.traverse(nil) {|st, parent|
          if st.respond_to? :remove_paren
            st.add_paren
            st.remove_paren
          end
        }
        node
      end

      # Traverses this children and itself with given block.
      #
      # If this element has children, traverse children first,
      # then yield block with parent and self.
      #
      # @param parent [Base] parent element.
      # @yield [parent, self] parent and this element.
      # @yieldparam [Base] self this element.
      # @yieldparam [Base] parent parent element.
      def traverse(parent, &block)

      end
    end

    # Class of ECMA262 Statement List
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.1
    class StatementList < Base
      attr_reader :statement_list

      def initialize(statement_list)
        @statement_list = statement_list #array
      end

      # Groups statements and reduce number of them as few as posibble.
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
          idx += 1
          while idx < new_sl.length
            if new_sl[idx].kind_of? StVar
              ;
            elsif new_sl[idx].kind_of? StFunc
              ;
            else
              new_sl[idx] = StEmpty.new
            end
            idx += 1
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

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@statement_list.collect{|s| s.deep_dup})
      end

      # Replaces children object
      # @see Base#replace
      def replace(from, to)
        idx = @statement_list.index(from)
        if idx
          @statement_list[idx] = to
        end
      end

      # Removes statement from statement list
      # @param st statement
      def remove(st)
        @statement_list.delete(st)
      end

      # Removes empty statement in this statement list
      def remove_empty_statement
        @statement_list.reject!{|x|
          x.class == StEmpty
        }
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        _self = self
        @statement_list.each do|st|
          st.traverse(self, &block)
        end
        yield parent, self
      end

      # compare object
      def ==(obj)
        @statement_list == obj.statement_list
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, @statement_list
      end

      # Returns number of the statements
      def length
        @statement_list.length
      end

      # return true if this can convert to expression.
      def to_exp?
        @statement_list.each do |s|
          return false if s.to_exp? == false
        end
        return true
      end

      # Converts statement list to expression and returns it.
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

      # Returns the statement at index
      # @param i index
      # @return [Statement] statement
      def [](i)
        @statement_list[i]
      end

      # Sets the statement at index.
      # @param i index
      # @param st statement
      def []=(i, st)
        @statement_list[i] = st
      end

      # Returns index of statement.
      # @param st statement.
      # @return [Fixnum] index of statement.
      def index(st)
        @statement_list.index(st)
      end
    end

    # Class of ECMA262 Source Elements
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 14
    class SourceElements < StatementList
      #
      # source_elements: [statement, statement, ...]
      #
      def initialize(source_elements)
        @statement_list = source_elements
      end

      # alias of statement_list
      def source_elements
        @statement_list
      end

      # alias of statement_list=
      def source_elements=(source_elements)
        @statement_list = source_elements
      end

      alias :source_elements :statement_list

      # compare object
      def ==(obj)
        statement_list == obj.statement_list
      end
    end

    # Class of ECMA262 Program
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 14
    class Prog < Base
      attr_reader :source_elements
      attr_reader :var_env
      attr_accessor :exe_context

      def initialize(var_env, source_elements)
        @source_elements = source_elements
        @var_env = var_env
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(var_env, source_elements.deep_dup)
      end

      # Replaces children object
      # @see Base#replace
      def replace(from, to)
        if from == @source_elements
          @source_elements = to
        end
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        @source_elements.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and self.source_elements == obj.source_elements
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, @source_elements
      end
    end
  end
end

