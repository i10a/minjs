module Minjs
  module ECMA262
    class Punctuator < Literal
      attr_reader :val

      @@sym = {}
      def initialize(val)
        @val = val.to_sym
      end

      def self.get(val)
        @@sym[val] ||= self.new(val)
      end

      def self.punctuator?(val)
        val = val.to_s
        if val == ">>>=" ||
           val == "===" || val == "!==" || val == ">>>" || val == "<<=" || val == ">>=" ||
           val == ">>" || val == "<=" || val == ">=" || val == "== " || val == "!=" ||
           val == "++" || val == "--" || val == "<<" || val == ">>" || val == "&&" ||
           val == "||" || val == "+=" || val == "-=" || val == "*=" || val == "%=" ||
           val == "&=" || val == "|=" || val == "^=" || val == "/="
           val.match(/\A[\{\}\(\)\[\]\.\;\,\<\>\+\-\*\%\&\|\^\!\~\?\:\=\/]/)
          true
        else
          false
        end
      end

      def to_s
        val.to_s
      end
    end
    PUNC_CONDIF = Punctuator.get('?')
    PUNC_CONDELSE = Punctuator.get(':')
    PUNC_LET = Punctuator.get('=')
    PUNC_DIVLET = Punctuator.get('/=')
    PUNC_MULLET = Punctuator.get('*=')
    PUNC_MODLET = Punctuator.get('%=')
    PUNC_ADDLET = Punctuator.get('+=')
    PUNC_SUBLET = Punctuator.get('-=')
    PUNC_LSHIFTLET = Punctuator.get('<<=')
    PUNC_RSHIFTLET = Punctuator.get('>>=')
    PUNC_URSHIFTLET = Punctuator.get('>>>=')
    PUNC_ANDLET = Punctuator.get('&=')
    PUNC_XORLET = Punctuator.get('^=')
    PUNC_ORLET = Punctuator.get('|=')
    PUNC_LOR = Punctuator.get('||')
    PUNC_LAND = Punctuator.get('&&')
    PUNC_OR = Punctuator.get('|')
    PUNC_XOR = Punctuator.get('^')
    PUNC_AND = Punctuator.get('&')
    PUNC_EQ = Punctuator.get('==')
    PUNC_NEQ = Punctuator.get('!=')
    PUNC_SEQ = Punctuator.get('===')
    PUNC_SNEQ = Punctuator.get('!==')
    PUNC_LT = Punctuator.get('<')
    PUNC_GT = Punctuator.get('>')
    PUNC_LTEQ = Punctuator.get('<=')
    PUNC_GTEQ = Punctuator.get('>=')
    PUNC_LSHIFT = Punctuator.get('<<')
    PUNC_RSHIFT = Punctuator.get('>>')
    PUNC_URSHIFT = Punctuator.get('>>>')
    PUNC_ADD = Punctuator.get('+')
    PUNC_SUB = Punctuator.get('-')
    PUNC_MUL = Punctuator.get('*')
    PUNC_DIV = Punctuator.get('/')
    PUNC_MOD = Punctuator.get('%')
    PUNC_INC = Punctuator.get('++')
    PUNC_DEC = Punctuator.get('--')
    PUNC_NOT = Punctuator.get('~')
    PUNC_LNOT = Punctuator.get('!')
    PUNC_LPARENTHESIS = Punctuator.get('(')
    PUNC_RPARENTHESIS = Punctuator.get(')')
    PUNC_LSQBRAC = Punctuator.get('[')
    PUNC_RSQBRAC = Punctuator.get(']')
    PUNC_LCURLYBRAC = Punctuator.get('{')
    PUNC_RCURLYBRAC = Punctuator.get('}')
    PUNC_COMMA = Punctuator.get(',')
    PUNC_COLON = Punctuator.get(':')
    PUNC_SEMICOLON = Punctuator.get(';')
    PUNC_PERIOD = Punctuator.get('.')
  end
end
