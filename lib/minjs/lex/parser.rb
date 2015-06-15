# coding: utf-8
require 'minjs/ctype'
require 'minjs/ecma262'

module Minjs::Lex
  # ECMA262 Parser class
  #
  # This class parses ECMA262 script language's source text
  # and convers it to elements (ECMA262::Base).
  class Parser
    include Minjs
    include Ctype
    include Lex::Program
    include Lex::Statement
    include Lex::Expression
    include Lex::Function

    attr_reader :pos
    attr_reader :codes

    # @param source_text [String] input source text
    # @option options :logger [Logger] logger for debug
    def initialize(source_text = "", options = {})
      source_text = source_text.gsub(/\r\n/, "\n")
      @codes = source_text.codepoints
      if !source_text.match(/\n\z/)
        @codes.push(10)
      end
      @pos = 0
      clear_cache
      @logger = options[:logger]

      @eval_nest = 0
    end

    # clear cache of ECMA262 elements
    def clear_cache
      @lit_cache = {}
      @lit_nextpos = {}
    end

    # Fetch next literal and forward position.
    #
    # @param hint [Symbol] hint of parsing. The hint must be one of the
    #   :regexp, :div, nil
    #   The hint parameter is used to determine next literal is division-mark or
    #   regular expression. because ECMA262 says:
    #
    #   There are no syntactic grammar contexts where both a leading division
    #   or division-assignment, and a leading RegularExpressionLiteral are permitted.
    #   This is not affected by semicolon insertion (see 7.9); in examples such as the following:
    #   To determine `/' is regular expression or not
    #
    def next_input_element(hint)
      if ret = @lit_cache[@pos]
        @pos = @lit_nextpos[@pos]
        @head_pos = @pos
        return ret
      end
      pos0 = @pos
      #
      # skip white space here, because ECMA262(5.1.2) says:
      #
      #   Simple white space and single-line comments are discarded and
      #   do not appear in the stream of input elements for the
      #   syntactic grammar.
      #
      while white_space or single_line_comment
      end

      ret = line_terminator || multi_line_comment || token
      if ret
        @lit_cache[pos0] = ret
        @lit_nextpos[pos0] = @pos
        @head_pos = @pos
        return ret
      end

      if @codes[@pos].nil?
        return nil
      end
      if hint.nil?
        if @codes[@pos] == 0x2f
          ECMA262::LIT_DIV_OR_REGEXP_LITERAL
        else
          nil
        end
      elsif hint == :div
        ret = div_punctuator
        if ret
          @lit_cache[pos0] = ret
          @lit_nextpos[pos0] = @pos
        end
        @head_pos = @pos
        return ret
      elsif hint == :regexp
        ret = regexp_literal
        if ret
          @lit_cache[pos0] = ret
          @lit_nextpos[pos0] = @pos
        end
        @head_pos = @pos
        return ret
      else
        if @codes[@pos] == 0x2f
          ECMA262::LIT_DIV_OR_REGEXP_LITERAL
        else
          nil
        end
      end
    end

    # Tests next literal is WhiteSpace or not.
    #
    # If literal is WhiteSpace
    # return ECMA262::WhiteSpace object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # Even if next literal is sequence of two or more white spaces,
    # this method returns only one white space.
    #
    # @return [ECMA262::WhiteSpace] element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.2
    def white_space
      if white_space?(@codes[@pos])
        begin
          @pos += 1
        end until !white_space?(@codes[@pos])
        return ECMA262::WhiteSpace.get
      else
        nil
      end
    end

    # Tests next literal is LineTerminator or not.
    #
    # If literal is LineTerminator
    # return ECMA262::LineTerminator object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # Even if next literal is sequence of two or more line terminators,
    # this method returns only one line terminator.
    #
    # @return [ECMA262::LineTerminator] element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.3
    def line_terminator
      if line_terminator?(@codes[@pos])
        begin
          @pos += 1
        end until !line_terminator?(@codes[@pos])
        return ECMA262::LineTerminator.get
      else
        nil
      end
    end

    # Tests next literal is Comment or not.
    #
    # If literal is Comment
    # return ECMA262::MultiLineComment or SingeLineComment object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.4
    def comment
      multi_line_comment || single_line_comment
    end

    # Tests next literal is MultiLineComment or not.
    #
    # If literal is MultiLineComment
    # return ECMA262::MultiLineComment object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.4
    def multi_line_comment
      # /*
      if @codes[@pos] == 0x2f and @codes[@pos + 1] == 0x2a
        @pos += 2
        pos0 = @pos
        # */
        while (code = @codes[@pos] != 0x2a) or @codes[@pos + 1] != 0x2f
          raise ParseError.new("no `*/' at end of comment", self) if code.nil?
          @pos += 1
        end
        @pos +=2
        return ECMA262::MultiLineComment.new(@codes[pos0...(@pos-2)].pack("U*"))
      else
        nil
      end
    end

    # Tests next literal is SinleLineComment or not.
    #
    # If literal is SingleLineComment
    # return ECMA262::SingleLineComment object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.4
    def single_line_comment
      # //
      if @codes[@pos] == 0x2f and @codes[@pos + 1] == 0x2f
        @pos += 2
        pos0 = @pos
        while (code = @codes[@pos]) and !line_terminator?(code)
          @pos += 1
        end
        return ECMA262::SingleLineComment.new(@codes[pos0...@pos].pack("U*"))
      else
        nil
      end
    end

    # Tests next literal is Token or not
    #
    # If literal is Token
    # return ECMA262::Base object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.5
    def token
      identifier_name || numeric_literal || punctuator || string_literal
    end

    def unicode_escape?
      # @codes[@pos] == 0x5c
      if @codes[@pos+1] == 0x75 #u
        if hex_digit?(@codes[@pos+2]) and
          hex_digit?(@codes[@pos+3]) and
          hex_digit?(@codes[@pos+4]) and
          hex_digit?(@codes[@pos+5])
          @codes[(@pos+2)..(@pos+5)].pack("U*").to_i(16)
        else
          raise ParseError.new("bad unicode escpae sequence", self)
        end
      else
        nil
      end
    end
    private :unicode_escape?

    # Tests next literal is IdentifierName or not
    #
    # If literal is IdentifierName
    # return ECMA262::IdentifierName object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.6
    def identifier_name
      return nil if (code = @codes[@pos]).nil?

      pos0 = @pos
      chars = []
      if code == 0x5c and ucode = unicode_escape? and identifier_start?(ucode)
        chars.push(ucode)
        @pos += 6
      elsif identifier_start?(code)
        chars.push(code)
        @pos += 1
      else
        return nil
      end

      while true
        code = @codes[@pos]
        if code == 0x5c and ucode = unicode_escape? and identifier_part?(ucode)
          chars.push(ucode)
          @pos += 6
        elsif identifier_part?(code)
          chars.push(code)
          @pos += 1
        else
          name = chars.pack("U*").to_sym
          return ECMA262::IdentifierName.get(name)
        end
      end
    end

    # Tests next literal is Punctuator or not
    #
    # If literal is Punctuator
    # return ECMA262::Punctuator object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.7
    def punctuator
      code0 = @codes[@pos]
      code1 = @codes[@pos+1]
      code2 = @codes[@pos+2]
      code3 = @codes[@pos+3]
      if false
      elsif code0 == 0x28 # (
        @pos += 1 # (
        return ECMA262::PUNC_LPARENTHESIS
      elsif code0 == 0x29 # )
        @pos += 1 # )
        return ECMA262::PUNC_RPARENTHESIS
      elsif code0 == 0x7b # {
        @pos += 1 # {
        return ECMA262::PUNC_LCURLYBRAC
      elsif code0 == 0x7d # }
        @pos += 1 # }
        return ECMA262::PUNC_RCURLYBRAC
      elsif code0 == 0x3b # ;
        @pos += 1 # ;
        return ECMA262::PUNC_SEMICOLON
      elsif code0 == 0x3d # =
        if code1 == 0x3d and code2 == 0x3d # ===
          @pos += 3
          return ECMA262::PUNC_SEQ
        end
        if code1 == 0x3d # ==
          @pos += 2
          return ECMA262::PUNC_EQ
        end
        @pos += 1 # =
        return ECMA262::PUNC_ASSIGN
      elsif code0 == 0x21 # !
        if code1 == 0x3d and code2 == 0x3d # !==
          @pos += 3
          return ECMA262::PUNC_SNEQ
        end
        if code1 == 0x3d # !=
          @pos += 2
          return ECMA262::PUNC_NEQ
        end
        @pos += 1 # !
        return ECMA262::PUNC_LNOT
      elsif code0 == 0x25 # %
        if code1 == 0x3d # %=
          @pos += 2
          return ECMA262::PUNC_MODASSIGN
        end
        @pos += 1 # %
        return ECMA262::PUNC_MOD
      elsif code0 == 0x26 # &
        if code1 == 0x3d # &=
          @pos += 2
          return ECMA262::PUNC_ANDASSIGN
        end
        if code1 == 0x26 # &&
          @pos += 2
          return ECMA262::PUNC_LAND
        end
        @pos += 1 # &
        return ECMA262::PUNC_AND
      elsif code0 == 0x2a # *
        if code1 == 0x3d # *=
          @pos += 2
          return ECMA262::PUNC_MULASSIGN
        end
        @pos += 1 # *
        return ECMA262::PUNC_MUL
      elsif code0 == 0x2b # +
        if code1 == 0x3d # +=
          @pos += 2
          return ECMA262::PUNC_ADDASSIGN
        end
        if code1 == 0x2b # ++
          @pos += 2
          return ECMA262::PUNC_INC
        end
        @pos += 1 # +
        return ECMA262::PUNC_ADD
      elsif code0 == 0x2c # ,
        @pos += 1 # ,
        return ECMA262::PUNC_COMMA
      elsif code0 == 0x2d # -
        if code1 == 0x3d # -=
          @pos += 2
          return ECMA262::PUNC_SUBASSIGN
        end
        if code1 == 0x2d # --
          @pos += 2
          return ECMA262::PUNC_DEC
        end
        @pos += 1 # -
        return ECMA262::PUNC_SUB
      elsif code0 == 0x2e # .
        @pos += 1 # .
        return ECMA262::PUNC_PERIOD
      elsif code0 == 0x3a # :
        @pos += 1 # :
        return ECMA262::PUNC_COLON
      elsif code0 == 0x3c # <
        if code1 == 0x3d # <=
          @pos += 2
          return ECMA262::PUNC_LTEQ
        end
        if code1 == 0x3c and code2 == 0x3d # <<=
          @pos += 3
          return ECMA262::PUNC_LSHIFTASSIGN
        end
        if code1 == 0x3c # <<
          @pos += 2
          return ECMA262::PUNC_LSHIFT
        end
        @pos += 1 # <
        return ECMA262::PUNC_LT
      elsif code0 == 0x3e # >
        if code1 == 0x3e and code2 == 0x3e and code3 == 0x3d # >>>=
          @pos += 4
          return ECMA262::PUNC_URSHIFTASSIGN
        end
        if code1 == 0x3e and code2 == 0x3e # >>>
          @pos += 3
          return ECMA262::PUNC_URSHIFT
        end
        if code1 == 0x3e and code2 == 0x3d # >>=
          @pos += 3
          return ECMA262::PUNC_RSHIFTASSIGN
        end
        if code1 == 0x3e # >>
          @pos += 2
          return ECMA262::PUNC_RSHIFT
        end
        if code1 == 0x3d # >=
          @pos += 2
          return ECMA262::PUNC_GTEQ
        end
        @pos += 1 # >
        return ECMA262::PUNC_GT
      elsif code0 == 0x3f # ?
        @pos += 1 # ?
        return ECMA262::PUNC_CONDIF
      elsif code0 == 0x5b # [
        @pos += 1 # [
        return ECMA262::PUNC_LSQBRAC
      elsif code0 == 0x5d # ]
        @pos += 1 # ]
        return ECMA262::PUNC_RSQBRAC
      elsif code0 == 0x5e # ^
        if code1 == 0x3d # ^=
          @pos += 2
          return ECMA262::PUNC_XORASSIGN
        end
        @pos += 1 # ^
        return ECMA262::PUNC_XOR
      elsif code0 == 0x7c # |
        if code1 == 0x7c # ||
          @pos += 2
          return ECMA262::PUNC_LOR
        end
        if code1 == 0x3d # |=
          @pos += 2
          return ECMA262::PUNC_ORASSIGN
        end
        @pos += 1 # |
        return ECMA262::PUNC_OR
      elsif code0 == 0x7e # ~
        @pos += 1 # ~
        return ECMA262::PUNC_NOT
      end
      nil
    end

    # Tests next literal is DivPunctuator or not.
    #
    # If literal is DivPunctuator
    # return ECMA262::PUNC_DIV or ECMA262::PUNC_DIVASSIGN object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.7
    def div_punctuator
      if @codes[@pos] == 0x2f
        if @codes[@pos+1] == 0x3d
          @pos += 2
          return ECMA262::PUNC_DIVASSIGN
        else
          @pos += 1
          return ECMA262::PUNC_DIV
        end
      end
      nil
    end

    # Tests next literal is RegExp or not.
    #
    # If literal is RegExp
    # return ECMA262::ECMA262RegExp object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @return [ECMA262::RegExp]
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.8.5
    def regexp_literal
      # RegularExpressionLiteral::
      # 	/ RegularExpressionBody / RegularExpressionFlags
      pos0 = @pos
      return nil unless @codes[@pos] == 0x2f

      body = regexp_body
      flags = regexp_flags
      return ECMA262::ECMA262RegExp.new(body, flags)
    end

    def regexp_body
      if @codes[@pos] == 0x2a
        raise ParseError.new("first character of regular expression is `*'", self)
      end
      pos0 = @pos
      @pos += 1
      while !(@codes[@pos] == 0x2f)
        if @codes[@pos].nil?
          raise ParseError.new("no `/' end of regular expression", self)
        end
        if line_terminator?(@codes[@pos])
          raise ParseError.new("regular expression has line terminator in body", self)
        end
        if @codes[@pos] == 0x5c # \
          @pos += 1
          if line_terminator?(@codes[@pos])
            raise ParseError.new("regular expression has line terminator in body", self)
          end
          @pos += 1
        elsif @codes[@pos] == 0x5b # [
          regexp_class
        else
          @pos += 1
        end
      end
      @pos += 1
      return @codes[(pos0+1)...(@pos-1)].pack("U*")
    end

    def regexp_class
      if @codes[@pos] != 0x5b
        raise ParseError.new('bad regular expression', self)
      end
      @pos += 1
      while !(@codes[@pos] == 0x5d)
        if @codes[@pos].nil?
          raise ParseError.new("no `]' end of regular expression class", self)
        end
        if line_terminator?(@codes[@pos])
          raise ParseError.new("regular expression has line terminator in body", self)
        end
        if @codes[@pos] == 0x5c # \
          @pos += 1
          if line_terminator?(@codes[@pos])
            raise ParseError.new("regular expression has line terminator in body", self)
          end
          @pos += 1
        else
          @pos += 1
        end
      end
      @pos += 1
    end

    def regexp_flags
      pos0 = @pos
      while(identifier_part?(@codes[@pos]))
        @pos += 1
      end
      return @codes[pos0...@pos].pack("U*")
    end

    private :regexp_flags, :regexp_class, :regexp_body

    # Tests next literal is NumericLiteral or not.
    #
    # If literal is NumericLiteral
    # return ECMA262::ECMA262Numeric object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @return [ECMA262::ECMA262Numeric]
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.8.3
    def numeric_literal
      hex_integer_literal || octal_integer_literal || decimal_literal
    end

    #7.8.3
    #
    # HexIntegerLiteral ::
    # 0x HexDigit
    # 0X HexDigit
    # HexIntegerLiteral HexDigit
    #
    def hex_integer_literal
      code = @codes[@pos]
      if code.nil?
        return nil
      #0x / 0X
      elsif code == 0x30 and (@codes[@pos+1] == 0x78 || @codes[@pos+1] == 0x58)
        @pos += 2
        pos0 = @pos
        while code = @codes[@pos] and hex_digit?(code)
          @pos += 1;
        end
        if identifier_start?(code)
          raise ParseError.new("The source character immediately following a NumericLiteral must not be an IdentifierStart or DecimalDigit", self)
        else
          return ECMA262::ECMA262Numeric.new(@codes[pos0...@pos].pack("U*").to_i(16))
        end
      else
        nil
      end
    end

    #B.1.1
    # OctalIntegerLiteral ::
    # 0 OctalDigit
    # OctalIntegerLiteral OctalDigit
    #
    def octal_integer_literal
      code = @codes[@pos]
      if code.nil?
        return nil
      elsif code == 0x30 and (code1 = @codes[@pos + 1]) >= 0x30 and code1 <= 0x37
        @pos += 1
        pos0 = @pos
        while code = @codes[@pos] and code >= 0x30 and code <= 0x37
          @pos += 1
        end
        if identifier_start?(code)
          raise ParseError.new("The source character immediately following a NumericLiteral must not be an IdentifierStart or DecimalDigit", self)
        else
          return ECMA262::ECMA262Numeric.new(@codes[pos0...@pos].pack("U*").to_i(8))
        end
      else
        nil
      end
    end

    # 7.8.3
    #
    # DecimalLiteral ::
    # DecimalIntegerLiteral . DecimalDigitsopt ExponentPartopt
    # . DecimalDigits ExponentPartopt
    # DecimalIntegerLiteral ExponentPartopt
    #
    def decimal_literal
      pos0 = @pos
      code = @codes[@pos]

      if code.nil?
        return nil
      elsif code == 0x2e #.
        @pos += 1
        f = decimal_digits
        if f.nil? #=> this period is punctuator
          @pos = pos0 + 1
          return ECMA262::PUNC_PERIOD
        end
        if (code = @codes[@pos]) == 0x65 || code == 0x45
          @pos += 1
          e = exponent_part
        end
        if identifier_start?(@codes[@pos])
          raise ParseError.new("The source character immediately following a NumericLiteral must not be an IdentifierStart or DecimalDigit", self)
        end

        return ECMA262::ECMA262Numeric.new('0', f, e)
      elsif code == 0x30 # zero
        i = "0"
        @pos += 1
        if @codes[@pos] == 0x2e #.
          @pos += 1
          f = decimal_digits
          if (code = @codes[@pos]) == 0x65 || code == 0x45 #e or E
            @pos += 1
            e = exponent_part
          end
        elsif (code = @codes[@pos]) == 0x65 || code == 0x45 #e or E
          @pos += 1
          e = exponent_part
        end
        if identifier_start?(@codes[@pos])
          raise ParseError.new("The source character immediately following a NumericLiteral must not be an IdentifierStart or DecimalDigit", self)
        end

        return ECMA262::ECMA262Numeric.new(i, f, e)
      elsif code >= 0x31 and code <= 0x39
        i = decimal_digits
        if @codes[@pos] == 0x2e #.
          @pos += 1
          f = decimal_digits
          if (code = @codes[@pos]) == 0x65 || code == 0x45 #e or E
            @pos += 1
            e = exponent_part
          end
        elsif (code = @codes[@pos]) == 0x65 || code == 0x45 #e or E
          @pos += 1
          e = exponent_part
        end
        if identifier_start?(@codes[@pos])
          raise ParseError.new("The source character immediately following a NumericLiteral must not be an IdentifierStart or DecimalDigit", self)
        end

        return ECMA262::ECMA262Numeric.new(i, f, e)
      end

      nil
    end

    # 7.8.3
    #
    # ExponentPart ::
    # ExponentIndicator SignedInteger
    #
    def exponent_part
      if (code = @codes[@pos]) == 0x2b
        @pos += 1
      elsif code == 0x2d
        @pos += 1
        neg = true
      end
      d = decimal_digits
      raise ParseError.new("unexpecting token", self) if d.nil?
      if neg
        e = "-#{d}"
      else
        e = d
      end
      e
    end

    #7.8.3
    #
    # DecimalDigit :: one of
    # 0 1 2 3 4 5 6 7 8 9
    #
    def decimal_digits
      pos0 = @pos
      if (code = @codes[@pos]) >= 0x30 and code <= 0x39
        @pos += 1
        while code = @codes[@pos] and code >= 0x30 and code <= 0x39
          @pos += 1
        end
        return @codes[pos0...@pos].pack("U*")
      else
        nil
      end
    end
    private :hex_integer_literal, :octal_integer_literal, :decimal_literal,
            :exponent_part, :decimal_digits

    # Tests next literal is StringLiteral or not.
    #
    # If literal is StringLiteral
    # return ECMA262::ECMA262String object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @return [ECMA262::ECMA262String]
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.8.4
    #
    def string_literal
      # StringLiteral ::
      # " DoubleStringCharactersopt "
      # ' SingleStringCharactersopt '
      #
      # DoubleStringCharacters ::
      # DoubleStringCharacter DoubleStringCharactersopt
      #
      # SingleStringCharacters ::
      # SingleStringCharacter SingleStringCharactersopt
      #
      # DoubleStringCharacter ::
      # SourceCharacter but not one of " or \ or LineTerminator
      # \ EscapeSequence
      # LineContinuation
      #
      # SingleStringCharacter ::
      # SourceCharacter but not one of ' or \ or LineTerminator
      # \ EscapeSequence
      # LineContinuation
      #
      if (code = @codes[@pos]) == 0x27 #'
        term = 0x27
      elsif code == 0x22 #"
        term = 0x22
      else
        return nil
      end
      @pos += 1
      pos0 = @pos

      str = []
      while (code = @codes[@pos])
        if code.nil?
          raise ParseError.new("no `#{term}' at end of string", self)
        elsif line_terminator?(code)
          raise ParseError.new("string has line terminator in body", self)
        elsif code == 0x5c #\
          @pos += 1
          str.push(escape_sequence)
        elsif code == term
          @pos += 1
          return ECMA262::ECMA262String.new(str.compact.pack("U*"))
        else
          @pos += 1
          str.push(code)
        end
      end
      nil
    end

    # 7.8.4
    # B.1.2
    #
    # EscapeSequence ::
    # CharacterEscapeSequence
    # 0 [lookahead ∉ DecimalDigit]
    # HexEscapeSequence
    # UnicodeEscapeSequence
    # OctalEscapeSequence

    def escape_sequence
      case (code = @codes[@pos])
#      when 0x30
#        @pos += 1
#        0
      when 0x27 #'
        @pos += 1
        0x27
      when 0x22 #"
        @pos += 1
        0x22
      when 0x5c #\
        @pos += 1
        0x5c
      when 0x62 #b
        @pos += 1
        0x08
      when 0x74 #t
        @pos += 1
        0x09
      when 0x6e #n
        @pos += 1
        0x0a
      when 0x76 #v
        @pos += 1
        0x0b
      when 0x66 #f
        @pos += 1
        0x0c
      when 0x72 #r
        @pos += 1
        0x0d
      when 0x78 #x
        #check
        t = @codes[(@pos+1)..(@pos+2)].pack("U*").to_i(16)
        @pos += 3
        t
      when 0x75 #u
        #check
        t = @codes[(@pos+1)..(@pos+4)].pack("U*").to_i(16)
        @pos += 5
        t
      else
        # line continuation
        if line_terminator?(code)
          @pos += 1
          nil
        # Annex B.1.2
        #
        # OctalEscapeSequence ::
        # OctalDigit [lookahead ∉ DecimalDigit]
        # ZeroToThree OctalDigit [lookahead ∉ DecimalDigit]
        # FourToSeven OctalDigit
        # ZeroToThree OctalDigit OctalDigit
        #
        # Note:
        #
        # A string such as the following is invalid
        # as a octal escape sequence.
        #
        # \19 or \319
        #
        # However, it is not to an error in most implementations.
        # Therefore, minjs also intepret it such way.
        #
        elsif octal_digit?(code)
          code1 = @codes[@pos+1]
          code2 = @codes[@pos+2]
          if code >= 0x30 and code <= 0x33
            if octal_digit?(code1)
              if octal_digit?(code2)
                @pos += 3
                (code - 0x30) * 64 + (code1 - 0x30) * 8 + (code2 - 0x30)
              else
                @pos += 2
                (code - 0x30) * 8 + (code1 - 0x30)
              end
            else
              @pos += 1
              code - 0x30
            end
          else #if code >= 0x34 and code <= 0x37
            if octal_digit?(code1)
              @pos += 2
              (code - 0x30) * 8 + (code1 - 0x30)
            else
              @pos += 1
              code - 0x30
            end
          end
        else
          @pos += 1
          code
        end
      end
    end
    private :escape_sequence

    # Returns true if posision is at end of file
    def eof?
      peek_lit(nil).nil?
    end

    #
    # check next literal is strictly equal to _l_ or not.
    # white spaces and line terminators are skipped and ignored.
    #
    # if next literal is not _l_, position is not forwarded
    # if next literal is _l_, position is forwarded
    #
    def eql_lit?(l, hint = nil)
      lit = peek_lit(hint)
      if lit.eql? l
        fwd_after_peek
        lit
      else
        nil
      end
    end

    #
    # check next literal is strictly equal to _l_ or not.
    # white spaces are skipped and ignored.
    # line terminators are not ignored.
    #
    # if next literal is not _l_, position is not forwarded
    # if next literal is _l_, position is forwarded
    #
    def eql_lit_nolt?(l, hint = nil)
      lit = peek_lit_nolt(hint)
      if lit.eql? l
        fwd_after_peek
        lit
      else
        nil
      end
    end

    #
    # check next literal is equal to _l_ or not.
    # white spaces and line terminators are skipped and ignored.
    #
    # if next literal is not _l_, position is not forwarded
    # if next literal is _l_, position is forwarded
    #
    def match_lit?(l, hint = nil)
      lit = peek_lit(hint)
      if lit == l
        fwd_after_peek
        lit
      else
        nil
      end
    end

    #
    # check next literal is equal to _l_ or not.
    # white spaces are skipped and ignored.
    # line terminators are not ignored.
    #
    # if next literal is not _l_, position is not forwarded
    # if next literal is _l_, position is forwarded
    #
    def match_lit_nolt?(l, hint = nil)
      lit = peek_lit_nolt(hint)
      if lit == l
        fwd_after_peek
        lit
      else
        nil
      end
    end

    #
    # fetch next literal.
    # position is not forwarded.
    # white spaces and line terminators are skipped and ignored.
    #
    def peek_lit(hint)
      pos0 = @pos
      while lit = next_input_element(hint) and (lit.ws? or lit.lt?)
      end
      @pos = pos0
      lit
    end

    # fetch next literal.
    #
    # position is not forwarded.
    # white spaces are skipped and ignored.
    # line terminators are not ignored.
    #
    def peek_lit_nolt(hint)
      pos0 = @pos
      while lit = next_input_element(hint) and lit.ws?
      end
      @pos = pos0
      lit
    end

    # Forwards position after calling peek_lit.
    #
    # This method quickly forward position after calling peek_lit.
    def fwd_after_peek
      @pos = @head_pos
    end

    #
    # fetch next literal.
    # position is forwarded.
    # white spaces and line terminators are skipped and ignored.
    #
    def fwd_lit(hint)
      while lit = next_input_element(hint) and (lit.ws? or lit.lt?)
      end
      lit
    end

    #
    # fetch next literal.
    # position is forwarded.
    # white spaces are skipped and ignored.
    # line terminators are not ignored.
    #
    def fwd_lit_nolt(hint)
      while lit = next_input_element(hint) and lit.ws?
      end
      lit
    end

    #
    # break <val> => position is rewind, then break with <val>
    # return <val> => position is rewind, then return <val>
    # next <val> => position is not rewind, then break with <val>
    #
    def eval_lit(&block)
      begin
        saved_pos = @pos
        @eval_nest += 1
        ret = yield
      ensure
        @eval_nest -= 1
        if ret.nil?
          @pos = saved_pos
          nil
        else
          if @eval_nest == 0
            #STDERR.puts "clear_cache [#{saved_pos}..#{@pos}]"
            clear_cache
          end
        end
      end
    end

    #
    # position to [row, col]
    #
    def row_col(pos)
      _pos = 0
      row = 0
      col = 1
      @codes.each do |code|
        break if _pos >= pos
        if line_terminator?(code)
          row += 1
          col = 0
        else
          col += 1
        end
        _pos += 1
      end
      return [row+1, col+1]
    end

    #
    # position to line
    #
    def line(pos)
      pos0 = pos1 = pos
      while true
        pos0 -= 1
        break if line_terminator?(@codes[pos0])
      end
      pos0 += 1

      while true
        break if line_terminator?(@codes[pos1])
        pos1 += 1
      end

      @codes[pos0..pos1].pack("U*")
    end

    # Returns string of input data around _pos_
    #
    # @param pos position
    # @param row row
    # @param col column
    # @return [String] string
    #
    def debug_str(pos = nil, row = 0, col = 0)
      if pos.nil?
        pos = @head_pos or @pos
      end

      t = ''
      if col >= 80
        t << @codes[(pos-80)..(pos+80)].pack("U*")
        col = 81
      else
        t << line(pos)
      end

      if col and col >= 1
        col = col - 1;
      end
      t << "\n"
      t << (' ' * col) + "^"
      t
    end
  end
end
