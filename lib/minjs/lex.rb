# coding: utf-8
require 'minjs/ctype'

module Minjs
  class Lex
    include Ctype

    attr_reader :pos
    attr_reader :error_pos
    attr_reader :codes

    def initialize(str = "", options = {})
      str = str.gsub(/\r\n/, "\n")
      @codes = str.codepoints
      if !str.match(/\n\z/)
        @codes.push(10)
      end
      @pos = 0
      @lit_cache = []
      @lit_nextpos = []
      @logger = options[:logger]
    end

    def clear_cache
      @lit_cache = []
      @lit_nextpos = []
    end

    def next_input_element(hint)
      if ret = @lit_cache[@pos]
        @pos = @lit_nextpos[@pos]
        @error_pos = @pos
        return ret
      end
      pos0 = @pos
      if ret = (white_space || line_terminator || comment || token)
        if ret
          @lit_cache[pos0] = ret
          @lit_nextpos[pos0] = @pos
        end
        @error_pos = @pos
        return ret
      end
      #
      # ECMA262 says:
      #
      # There are no syntactic grammar contexts where both a leading division
      # or division-assignment, and a leading RegularExpressionLiteral are permitted.
      # This is not affected by semicolon insertion (see 7.9); in examples such as the following:
      # To determine `/' is regular expression or not
      #
      if hint.nil?
        ECMA262::LIT_DIV_OR_REGEXP_LITERAL
      elsif hint == :div
        ret = div_punctuator
        if ret
          @lit_cache[pos0] = ret
          @lit_nextpos[pos0] = @pos
        end
        @error_pos = @pos
        return ret
      elsif hint == :regexp
        ret = regexp_literal
        if ret
          @lit_cache[pos0] = ret
          @lit_nextpos[pos0] = @pos
        end
        @error_pos = @pos
        return ret
      else
        ECMA262::LIT_DIV_OR_REGEXP_LITERAL
      end
    end

    # 7.2
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

    #7.3
    def line_terminator
      if line_terminator?(@codes[@pos])
        begin
          @pos += 1
        end until !line_terminator?(@codes[@pos])
        return ECMA262::LineFeed.get
      else
        nil
      end
    end

    #7.4
    def comment
      multi_line_comment || single_line_comment
    end

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

    def single_line_comment
      # //
      if @codes[@pos] == 0x2f and @codes[@pos + 1] == 0x2f
        @pos += 2
        pos0 = @pos
        while (code = @codes[@pos]) and !line_terminator?(code)
          @pos += 1
        end
        if @codes[@pos].nil?
          return ECMA262::SingleLineComment.new(@codes[pos0...@pos].pack("U*") + "\n")
        else
          return ECMA262::SingleLineComment.new(@codes[pos0...@pos].pack("U*"))
        end
      else
        nil
      end
    end

    #
    # 7.5 tokens
    #
    def token
      identifier_name || numeric_literal || punctuator || string_literal
    end

    #
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
          return ECMA262::IdentifierName.get(nil, name)
        end
      end
    end

    def punctuator
      code0 = @codes[@pos]
      code1 = @codes[@pos+1]
      code2 = @codes[@pos+2]
      code3 = @codes[@pos+3]
      if code0 == 0x21 # !
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
          return ECMA262::PUNC_MODLET
        end
        @pos += 1 # %
        return ECMA262::PUNC_MOD
      elsif code0 == 0x26 # &
        if code1 == 0x3d # &=
          @pos += 2
          return ECMA262::PUNC_ANDLET
        end
        if code1 == 0x26 # &&
          @pos += 2
          return ECMA262::PUNC_LAND
        end
        @pos += 1 # &
        return ECMA262::PUNC_AND
      elsif code0 == 0x28 # (
        @pos += 1 # (
        return ECMA262::PUNC_LPARENTHESIS
      elsif code0 == 0x29 # )
        @pos += 1 # )
        return ECMA262::PUNC_RPARENTHESIS
      elsif code0 == 0x2a # *
        if code1 == 0x3d # *=
          @pos += 2
          return ECMA262::PUNC_MULLET
        end
        @pos += 1 # *
        return ECMA262::PUNC_MUL
      elsif code0 == 0x2b # +
        if code1 == 0x3d # +=
          @pos += 2
          return ECMA262::PUNC_ADDLET
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
          return ECMA262::PUNC_SUBLET
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
      elsif code0 == 0x3b # ;
        @pos += 1 # ;
        return ECMA262::PUNC_SEMICOLON
      elsif code0 == 0x3c # <
        if code1 == 0x3d # <=
          @pos += 2
          return ECMA262::PUNC_LTEQ
        end
        if code1 == 0x3c and code2 == 0x3d # <<=
          @pos += 3
          return ECMA262::PUNC_LSHIFTLET
        end
        if code1 == 0x3c # <<
          @pos += 2
          return ECMA262::PUNC_LSHIFT
        end
        @pos += 1 # <
        return ECMA262::PUNC_LT
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
        return ECMA262::PUNC_LET
      elsif code0 == 0x3e # >
        if code1 == 0x3e and code2 == 0x3e and code3 == 0x3d # >>>=
          @pos += 4
          return ECMA262::PUNC_URSHIFTLET
        end
        if code1 == 0x3e and code2 == 0x3e # >>>
          @pos += 3
          return ECMA262::PUNC_URSHIFT
        end
        if code1 == 0x3e and code2 == 0x3d # >>=
          @pos += 3
          return ECMA262::PUNC_RSHIFTLET
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
          return ECMA262::PUNC_XORLET
        end
        @pos += 1 # ^
        return ECMA262::PUNC_XOR
      elsif code0 == 0x7b # {
        @pos += 1 # {
        return ECMA262::PUNC_LCURLYBRAC
      elsif code0 == 0x7c # |
        if code1 == 0x7c # ||
          @pos += 2
          return ECMA262::PUNC_LOR
        end
        if code1 == 0x3d # |=
          @pos += 2
          return ECMA262::PUNC_ORLET
        end
        @pos += 1 # |
        return ECMA262::PUNC_OR
      elsif code0 == 0x7d # }
        @pos += 1 # }
        return ECMA262::PUNC_RCURLYBRAC
      elsif code0 == 0x7e # ~
        @pos += 1 # ~
        return ECMA262::PUNC_NOT
      end
      nil
    end

    def div_punctuator
      if @codes[@pos] == 0x2f
        if @codes[@pos+1] == 0x3d
          @pos += 2
          return ECMA262::PUNC_DIVLET
        else
          @pos += 1
          return ECMA262::PUNC_DIV
        end
      end
      nil
    end

    #
    # 7.8.5
    #
    # RegularExpressionLiteral::
    # 	/ RegularExpressionBody / RegularExpressionFlags
    #
    def regexp_literal
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

    #7.8.3
    #B.1.1
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
      if neg
        e = "-#{decimal_digits}"
      else
        e = decimal_digits
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

    #7.8.4
    #
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
    def string_literal
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

    def eof?(pos = nil)
      if pos.nil?
        @codes[@pos].nil?
      else
        @codes[pos].nil?
      end
    end

    #
    # check next literal is strictly equal to 'l' or not.
    # white spaces and line terminators are skipped and ignored.
    #
    # if next literal is not 'l', position is not forwarded
    # if next literal is 'l', position is forwarded
    #
    def eql_lit?(l, hint = nil)
      pos0 = @pos
      while lit = next_input_element(hint) and (lit.ws? or lit.lt?)
      end

      if lit.eql? l
        lit
      else
        @pos = pos0
        nil
      end
    end

    #
    # check next literal is equal to 'l' or not.
    # white spaces are skipped and ignored.
    # line terminators are not ignored.
    #
    # if next literal is not 'l', position is not forwarded
    # if next literal is 'l', position is forwarded
    #
    def eql_lit_nolt?(l)
      pos0 = @pos
      while lit = next_input_element(nil) and lit.ws?
      end

      if lit.eql? l
        lit
      else
        @pos = pos0
        nil
      end
    end

    #
    # check next literal is equal to 'l' or not.
    # white spaces and line terminators are skipped and ignored.
    #
    # if next literal is not 'l', position is not forwarded
    # if next literal is 'l', position is forwarded
    #
    def match_lit?(l, hint = nil)
      pos0 = @pos
      while lit = next_input_element(hint) and (lit.ws? or lit.lt?)
      end

      if lit == l
        lit
      else
        @pos = pos0
        nil
      end
    end

    #
    # check next literal is equal to 'l' or not.
    # white spaces are skipped and ignored.
    # line terminators are not ignored.
    #
    # if next literal is not 'l', position is not forwarded
    # if next literal is 'l', position is forwarded
    #
    def match_lit_nolt?(l)
      pos0 = @pos
      while lit = next_input_element(nil) and lit.ws?
      end

      if lit == l
        lit
      else
        @pos = pos0
        nil
      end
    end

    #
    # fetch next literal.
    # position is not forwarded.
    # white spaces and line terminators are skipped and ignored.
    #
    def next_lit(hint = nil)
      pos0 = @pos
      while lit = next_input_element(hint) and (lit.ws? or lit.lt?)
      end
      @pos = pos0
      lit
    end

    #
    # fetch next literal.
    # position is not forwarded.
    # white spaces are skipped and ignored.
    # line terminators are not ignored.
    #
    def next_lit_nolt(hint)
      pos0 = @pos
      while lit = next_input_element(hint) and lit.ws?
      end
      @pos = pos0
      lit
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

    def debug_str(pos = nil, line = nil, col = nil)
      if pos.nil?
        pos = @error_pos
        if pos.nil?
          pos = @pos
        end
      end
      if pos > 20
        pos -= 20
        pos0 = 20
      elsif pos >= 0
        pos0 = pos
        pos = 0
      end
      if col and col >= 1
        pos0 = col - 1;
      end
      t = ''
      t << @codes[pos..(pos+80)].pack("U*")
      t << "\n"
      t << (' ' * pos0) + "^"
      t
    end

    def debug_lit(pos = nil)
      if pos.nil?
        pos = @error_pos
        if pos.nil?
          pos = @pos
        end
      end
      if pos > 20
        pos -= 20
        pos0 = 20
      elsif pos >= 0
        pos0 = pos
        pos = 0
      end
      #STDERR.puts pos0
      STDERR.puts @codes[pos..(pos+80)].collect{|u| u == 10 ? 0x20 : u}.pack("U*")
      STDERR.puts (' ' * pos0) + "^"
    end
    #
    # break <val> => position is rewind, then break with <val>
    # return <val> => position is rewind, then return <val>
    # next <val> => position is not rewind, then break with <val>
    #
    def eval_lit(&block)
      begin
        saved_pos = @pos
        ret = yield
      ensure
        if ret.nil?
          #@error_pos = @pos
          @pos = saved_pos
          nil
        end
      end
    end

    def line_col(pos)
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
  end
end
