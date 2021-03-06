# coding: utf-8
module Minjs
  module ECMA262
    # class of Environment Record
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 10.2.1
    class EnvRecord
      attr_reader :binding
      attr_reader :options

      def initialize(options = {})
        @binding = {}
        @options = {}
      end

      # CreateMutableBinding(N, D)
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 10.2.1
      def create_mutable_binding(n, d, options = {})
        if n.kind_of? IdentifierName
          n = n.val
        end
        @binding[n] = {:value => nil}
      end

      # SetMutableBinding(N, V, S)
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 10.2.1
      def set_mutable_binding(n, v, s, options = {})
        if n.kind_of? IdentifierName
          n = n.val
        end
        @binding[n][:value] = v
        @binding[n].merge!(options || {})
      end
    end

    # class of Declarative Environment Record
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 10.2.1.1
    class DeclarativeEnvRecord < EnvRecord
    end

    # class of Object Environment Record
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 10.2.1.2
    class ObjectEnvRecord < EnvRecord
    end

    # class of Lexical Environment
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 10.2
    class LexEnv
      attr_accessor :record
      attr_reader :outer
      attr_reader :type

      def initialize(options = {})
        @outer = options[:outer]
        @type = (options[:type] || :declarative)
        if options[:record]
          @record = ObjectEnvRecord.new
        elsif options[:type] == :declarative
          @record = DeclarativeEnvRecord.new
        elsif options[:type] == :object or true
          @record = ObjectEnvRecord.new
        end
      end

      # NewDeclarativeEnvironment(E)
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 10.2.2.2
      def new_declarative_env(outer = nil)
        e = LexEnv.new(outer: (outer || self), type: :declarative)
      end

      # NewDeclarativeEnvironment(E)
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 10.2.2.2
      def self.new_declarative_env(e)
        env = LexEnv.new(outer: e, type: :declarative)
      end

      # NewObjectEnvironment(O, E)
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 10.2.2.3
      def new_object_env(object, outer = nil)#TODO
        raise 'TODO'
        e = LexEnv.new(outer: (outer || self), type: :object)
        object.val.each do |k, v|
          if k.id_name?
            e.create_mutable_binding(k)
            e.set_mutable_binding(k, v)
          end
        end
      end

      # debug
      def debug
        STDERR.puts @record.binding.keys.join(", ")
      end
    end

    # Class of Execution Contexts
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 10.3
    class ExeContext
      attr_accessor :lex_env
      attr_accessor :var_env
      attr_accessor :this_binding
      def initialize(options = {})
        @var_env = LexEnv.new(options)
        @lex_env = LexEnv.new(options)
        @this_binding = nil
      end
    end
  end
end
