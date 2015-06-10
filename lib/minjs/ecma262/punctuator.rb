module Minjs
  module ECMA262
    # ECMA262 punctuator element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.7
    class Punctuator < Literal
      attr_reader :val

      @@sym = {}

      def initialize(val)
        @val = val.to_sym
      end

      # Returns punctuator object representation of string.
      #
      # @param val [String] punctuator
      def self.get(val)
        @@sym[val] ||= self.new(val)
      end

      # Returns a string containg the representation of punctuator.
      def to_s
        val.to_s
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js
        val.to_s
      end

      # Return true if punctuator equals to other.
      #
      # @param obj other element.
      def ==(obj)
        self.class == obj.class and self.val == obj.val
      end
    end
    #punctuator
    PUNC_CONDIF = Punctuator.get('?')
    #punctuator
    PUNC_LET = Punctuator.get('=')
    #punctuator
    PUNC_DIVLET = Punctuator.get('/=')
    #punctuator
    PUNC_MULLET = Punctuator.get('*=')
    #punctuator
    PUNC_MODLET = Punctuator.get('%=')
    #punctuator
    PUNC_ADDLET = Punctuator.get('+=')
    #punctuator
    PUNC_SUBLET = Punctuator.get('-=')
    #punctuator
    PUNC_LSHIFTLET = Punctuator.get('<<=')
    #punctuator
    PUNC_RSHIFTLET = Punctuator.get('>>=')
    #punctuator
    PUNC_URSHIFTLET = Punctuator.get('>>>=')
    #punctuator
    PUNC_ANDLET = Punctuator.get('&=')
    #punctuator
    PUNC_XORLET = Punctuator.get('^=')
    #punctuator
    PUNC_ORLET = Punctuator.get('|=')
    #punctuator
    PUNC_LOR = Punctuator.get('||')
    #punctuator
    PUNC_LAND = Punctuator.get('&&')
    #punctuator
    PUNC_OR = Punctuator.get('|')
    #punctuator
    PUNC_XOR = Punctuator.get('^')
    #punctuator
    PUNC_AND = Punctuator.get('&')
    #punctuator
    PUNC_EQ = Punctuator.get('==')
    #punctuator
    PUNC_NEQ = Punctuator.get('!=')
    #punctuator
    PUNC_SEQ = Punctuator.get('===')
    #punctuator
    PUNC_SNEQ = Punctuator.get('!==')
    #punctuator
    PUNC_LT = Punctuator.get('<')
    #punctuator
    PUNC_GT = Punctuator.get('>')
    #punctuator
    PUNC_LTEQ = Punctuator.get('<=')
    #punctuator
    PUNC_GTEQ = Punctuator.get('>=')
    #punctuator
    PUNC_LSHIFT = Punctuator.get('<<')
    #punctuator
    PUNC_RSHIFT = Punctuator.get('>>')
    #punctuator
    PUNC_URSHIFT = Punctuator.get('>>>')
    #punctuator
    PUNC_ADD = Punctuator.get('+')
    #punctuator
    PUNC_SUB = Punctuator.get('-')
    #punctuator
    PUNC_MUL = Punctuator.get('*')
    #punctuator
    PUNC_DIV = Punctuator.get('/')
    #punctuator
    PUNC_MOD = Punctuator.get('%')
    #punctuator
    PUNC_INC = Punctuator.get('++')
    #punctuator
    PUNC_DEC = Punctuator.get('--')
    #punctuator
    PUNC_NOT = Punctuator.get('~')
    #punctuator
    PUNC_LNOT = Punctuator.get('!')
    #punctuator
    PUNC_LPARENTHESIS = Punctuator.get('(')
    #punctuator
    PUNC_RPARENTHESIS = Punctuator.get(')')
    #punctuator
    PUNC_LSQBRAC = Punctuator.get('[')
    #punctuator
    PUNC_RSQBRAC = Punctuator.get(']')
    #punctuator
    PUNC_LCURLYBRAC = Punctuator.get('{')
    #punctuator
    PUNC_RCURLYBRAC = Punctuator.get('}')
    #punctuator
    PUNC_COMMA = Punctuator.get(',')
    #punctuator
    PUNC_COLON = Punctuator.get(':')
    #punctuator
    PUNC_SEMICOLON = Punctuator.get(';')
    #punctuator
    PUNC_PERIOD = Punctuator.get('.')

    Punctuator.class_eval {
      private_class_method :new
    }
  end
end
