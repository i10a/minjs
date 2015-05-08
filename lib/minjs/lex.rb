require 'minjs/ctype'

module Minjs
  class Lex
    include Ctype

    attr_reader :pos
    attr_reader :error_pos

    def initialize(str = "", options = {})
      str = str.gsub(/\r\n/, "\n")
      @codes = str.codepoints
      @pos = 0
      @lit_cache = []
      @lit_next = []
      if options[:debug]
        @debug = true
      end
    end

    def next_input_element(options = {})
      if @lit_cache[@pos]
        ret = @lit_cache[@pos]
        @pos = @lit_next[@pos]
        return ret
      end
      if ret = (white_space || line_terminator || comment || token)
        return ret
      end
      #
      # ECMA262 say:
      #
      # There are no syntactic grammar contexts where both a leading division
      # or division-assignment, and a leading RegularExpressionLiteral are permitted.
      # This is not affected by semicolon insertion (see 7.9); in examples such as the following:
      # To determine `/' is regular expression or not
      #
      #
      if options[:hint] == :div
        div_punctuator
      elsif options[:hint] == :regexp
        regexp_literal
      else
        div_punctuator
        #raise 'no hint'
      end
    end

    # 7.2
    def white_space
      code = @codes[@pos]
      if white_space?(code)
        while true
          @pos += 1
          code = @codes[@pos]
          break unless white_space?(code)
        end
        return ECMA262::WhiteSpace.get
      else
        nil
      end
    end

    #7.3
    def line_terminator
      code = @codes[@pos]
      if line_terminator?(code)
        while true
          @pos += 1
          code = @codes[@pos]
          break unless line_terminator?(code)
        end
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
      if @codes[@pos] == 0x2f and @codes[@pos + 1] == 0x2a
        @pos = @pos + 2
        pos0 = @pos
        while @codes[@pos] != 0x2a or @codes[@pos + 1] != 0x2f
          @pos = @pos + 1
          if @codes[@pos] == 0x0a ||
             @codes[@pos] == 0x0d ||
             @codes[@pos] == 0x2028 ||
             @codes[@pos] == 0x2029
            lf = true
          end
        end
        @pos = @pos + 2
        return ECMA262::MultiLineComment.new(@codes[pos0...(@pos-2)].pack("U*"), lf)
        #return ECMA262::LineFeed.get
      else
        nil
      end
    end

    def single_line_comment
      if @codes[@pos] == 0x2f and @codes[@pos + 1] == 0x2f
        @pos = @pos + 2
        pos0 = @pos
        while true
          code = @codes[@pos]
          if (code == 0x0a || code == 0x0d || code == 0x2028 || code == 0x2029)
            return ECMA262::SingleLineComment.new(@codes[pos0...@pos].pack("U*"))
            #return ECMA262::WhiteSpace.get
          else
            @pos += 1
          end
        end
      else
        nil
      end
    end

    #
    # 7.5 tokens
    #
    def token
      pos0 = @pos
      ret = (identifier_name || numeric_literal || punctuator || string_literal)
      if ret
        @lit_cache[pos0] = ret
        @lit_next[pos0] = @pos
      end
      ret
    end

    def identifier_name
      pos0 = @pos
      code = @codes[@pos]
      return nil if code.nil?
      if identifier_start?(code)
        while true
          @pos += 1
          code = @codes[@pos]
          if code.nil?
            break
          elsif identifier_part?(code)
            ;#
          else
            return ECMA262::IdentifierName.new(nil, @codes[pos0...@pos].pack("U*").to_sym)
          end
        end
      end
    end

    def punctuator
      code0 = @codes[@pos]
      code1 = @codes[@pos+1]
      code2 = @codes[@pos+2]
      code3 = @codes[@pos+3]
      if false
      elsif (code0 == 0x3e and code1 == 0x3e and code2 == 0x3e and code3 == 0x3d)
        @pos += 4
        return ECMA262::Punctuator.get('>>>=')
      elsif (code0 == 0x3d and code1 == 0x3d and code2 == 0x3d)
        @pos += 3
        return ECMA262::Punctuator.get('===')
      elsif (code0 == 0x21 and code1 == 0x3d and code2 == 0x3d)
        @pos += 3
        return ECMA262::Punctuator.get('!==')
      elsif (code0 == 0x3e and code1 == 0x3e and code2 == 0x3e)
        @pos += 3
        return ECMA262::Punctuator.get('>>>')
      elsif (code0 == 0x3c and code1 == 0x3c and code2 == 0x3d)
        @pos += 3
        return ECMA262::Punctuator.get('<<=')
      elsif (code0 == 0x3e and code1 == 0x3e and code2 == 0x3d)
        @pos += 3
        return ECMA262::Punctuator.get('>>=')
      elsif (code0 == 0x3e and code1 == 0x3e)
        @pos += 2
        return ECMA262::Punctuator.get('>>')
      elsif (code0 == 0x3c and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('<=')
      elsif (code0 == 0x3e and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('>=')
      elsif (code0 == 0x3d and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('==')
      elsif (code0 == 0x21 and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('!=')
      elsif (code0 == 0x2b and code1 == 0x2b)
        @pos += 2
        return ECMA262::Punctuator.get('++')
      elsif (code0 == 0x2d and code1 == 0x2d)
        @pos += 2
        return ECMA262::Punctuator.get('--')
      elsif (code0 == 0x3c and code1 == 0x3c)
        @pos += 2
        return ECMA262::Punctuator.get('<<')
      elsif (code0 == 0x3e and code1 == 0x3e)
        @pos += 2
        return ECMA262::Punctuator.get('>>')
      elsif (code0 == 0x26 and code1 == 0x26)
        @pos += 2
        return ECMA262::Punctuator.get('&&')
      elsif (code0 == 0x7c and code1 == 0x7c)
        @pos += 2
        return ECMA262::Punctuator.get('||')
      elsif (code0 == 0x2b and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('+=')
      elsif (code0 == 0x2d and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('-=')
      elsif (code0 == 0x2a and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('*=')
      elsif (code0 == 0x25 and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('%=')
      elsif (code0 == 0x26 and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('&=')
      elsif (code0 == 0x7c and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('|=')
      elsif (code0 == 0x5e and code1 == 0x3d)
        @pos += 2
        return ECMA262::Punctuator.get('^=')
      elsif (code0 == 0x7b)
        @pos += 1
        return ECMA262::Punctuator.get('{')
      elsif (code0 == 0x7d)
        @pos += 1
        return ECMA262::Punctuator.get('}')
      elsif (code0 == 0x28)
        @pos += 1
        return ECMA262::Punctuator.get('(')
      elsif (code0 == 0x29)
        @pos += 1
        return ECMA262::Punctuator.get(')')
      elsif (code0 == 0x5b)
        @pos += 1
        return ECMA262::Punctuator.get('[')
      elsif (code0 == 0x5d)
        @pos += 1
        return ECMA262::Punctuator.get(']')
      elsif (code0 == 0x2e)
        @pos += 1
        return ECMA262::Punctuator.get('.')
      elsif (code0 == 0x3b)
        @pos += 1
        return ECMA262::Punctuator.get(';')
      elsif (code0 == 0x2c)
        @pos += 1
        return ECMA262::Punctuator.get(',')
      elsif (code0 == 0x3c)
        @pos += 1
        return ECMA262::Punctuator.get('<')
      elsif (code0 == 0x3e)
        @pos += 1
        return ECMA262::Punctuator.get('>')
      elsif (code0 == 0x2b)
        @pos += 1
        return ECMA262::Punctuator.get('+')
      elsif (code0 == 0x2d)
        @pos += 1
        return ECMA262::Punctuator.get('-')
      elsif (code0 == 0x2a)
        @pos += 1
        return ECMA262::Punctuator.get('*')
      elsif (code0 == 0x25)
        @pos += 1
        return ECMA262::Punctuator.get('%')
      elsif (code0 == 0x26)
        @pos += 1
        return ECMA262::Punctuator.get('&')
      elsif (code0 == 0x7c)
        @pos += 1
        return ECMA262::Punctuator.get('|')
      elsif (code0 == 0x5e)
        @pos += 1
        return ECMA262::Punctuator.get('^')
      elsif (code0 == 0x21)
        @pos += 1
        return ECMA262::Punctuator.get('!')
      elsif (code0 == 0x7e)
        @pos += 1
        return ECMA262::Punctuator.get('~')
      elsif (code0 == 0x3f)
        @pos += 1
        return ECMA262::Punctuator.get('?')
      elsif (code0 == 0x3a)
        @pos += 1
        return ECMA262::Punctuator.get(':')
      elsif (code0 == 0x3d)
        @pos += 1
        return ECMA262::Punctuator.get('=')
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

    #TODO..
    def regexp_literal
      pos0 = @pos
      if @codes[@pos] == 0x2f
        while @codes[@pos]
          @pos += 1
          code = @codes[@pos]
          if code == 0x5c
            @pos += 1
          elsif code == 0x2f
            @pos += 1
            while @codes[@pos]
              if (@codes[@pos] >= 0x61 and @codes[@pos] <= 0x7a) or
                 (@codes[@pos] >= 0x41 and @codes[@pos] <= 0x5a)
                @pos += 1
              else
                break
              end
            end
            return ECMA262::ECMA262RegExp.new(@codes[pos0...@pos].pack("U*"))
          end
        end
      end
      #fail...
      @pos = pos0
      nil
    end

    #7.8.3
    def numeric_literal
      code = @codes[@pos]
      return nil if code.nil?

      hex_integer_literal || decimal_literal
    end

    def hex_integer_literal
      pos0 = @pos
      # 0x.... or 0X....
      code = @codes[@pos]
      if code == 0x30 and (@codes[@pos+1] == 0x78 || @codes[@pos+1] == 0x58) #hex integer
        @pos += 2
        while true
          code = @codes[@pos]
          if (code >= 0x30 and code <= 0x39) || (code >= 0x41 and code <= 0x4f) || (code >= 0x61 and code <= 0x6f)
          else
            return ECMA262::ECMA262Numeric.new(@codes[(pos0+2)...@pos].pack("U*").to_i(16))
          end
          @pos += 1
        end
      else
        nil
      end
    end

    def decimal_literal
      pos0 = @pos
      code = @codes[@pos]
      if code == 0x2e #.
        @pos += 1
        f = decimal_digits
        if f.nil?
          @pos = pos0
          return nil
        end
        if @codes[@pos] == 0x65 || @codes[@pos] == 0x45
          @pos += 1
          e = exp_part
        end
        return ECMA262::ECMA262Numeric.new(0, f, e)
      else
        nil
      end
      if code >= 0x30 and code <= 0x39
        i = decimal_digits
        if @codes[@pos] == 0x2e
          @pos += 1
          f = decimal_digits
          if @codes[@pos] == 0x65 || @codes[@pos] == 0x45
            @pos += 1
            e = exp_part
          end
        elsif @codes[@pos] == 0x65 || @codes[@pos] == 0x45
          @pos += 1
          e = exp_part
        end
        return ECMA262::ECMA262Numeric.new(i, f, e)
      end
    end

    def exp_part
      if @codes[@pos] == 0x2b
        @pos += 1
      elsif @codes[@pos] == 0x2d
        @pos += 1
        neg = true
      end
      if neg
        e = -decimal_digits
      else
        e = decimal_digits
      end
      e
    end

    def decimal_digits
      pos0 = @pos
      code = @codes[@pos]
      if code >= 0x30 and code <= 0x39
        @pos += 1
        while true
          code = @codes[@pos]
          if code >= 0x30 and code <= 0x39
            @pos += 1
          else
            return @codes[pos0...@pos].pack("U*").to_i
          end
        end
      else
        nil
      end
    end

    #7.8.4
    def string_literal
      code = @codes[@pos]
      return nil if code.nil?
      pos0 = @pos
      if code == 0x27 #'
        str = ''
        while @codes[@pos]
          @pos += 1
          code = @codes[@pos]
          if code == 0x5c
            @pos += 1
            str << esc_string
          elsif code == 0x27 or code.nil?
            @pos += 1
            return ECMA262::ECMA262String.new(str)
          else
            str << code
          end
        end
      elsif code == 0x22 #"
        str = ''
        while @codes[@pos]
          @pos += 1
          code = @codes[@pos]
          if code == 0x5c
            @pos += 1
            str << esc_string
          elsif code == 0x22 or code.nil?
            @pos += 1
            return ECMA262::ECMA262String.new(str)
          else
            str << code
          end
        end
      end
      nil
    end

    # Annex B
    def octal?(char)
      char >= 0x30 and char <= 0x39
    end

    def esc_string
      case @codes[@pos]
      #      when 0x30
      #        "\u{0}"
      when 0x27
        "\'"
      when 0x22
        "\""
      when 0x5c
        "\\"
      when 0x62 #b
        "\u{0008}"
      when 0x74 #t
        "\u{0009}"
      when 0x6e #n
        "\u{000a}"
      when 0x76 #v
        "\u{000b}"
      when 0x66 #f
        "\u{000c}"
      when 0x72 #r
        "\u{000d}"
      when 0x78 #x
        t = [[@codes[@pos+1], @codes[@pos+2]].pack("U*").to_i(16)].pack("U*")
        @pos += 2
        t
      when 0x75 #u
        t = [[@codes[@pos+1], @codes[@pos+2], @codes[@pos+3], @codes[@pos+4]].pack("U*").to_i(16)].pack("U*")
        @pos += 4
        t
      else
        #
        # octal
        # Annex B
        if octal?(@codes[@pos])
          oct = 0
          while octal?(@codes[@pos])
            oct *= 8
            oct += (@codes[@pos] - 0x30)
            @pos += 1
          end
          [oct].pack("U*")
        else
          [@codes[@pos]].pack("U*")
        end
      end
    end

    def eof?(pos = nil)
      if pos.nil?
        pos = @pos
      end
      @codes[pos].nil?
    end

    #
    # check next literal is 'l' or not
    # if next literal is not 'l', position is not forwarded
    # if next literal is 'l', position is forwarded
    #
    def match_lit(l, options = {})
      eval_lit {
        t = fwd_lit(options)
        STDERR.puts "match_lit #{t} <=> #{l} #{t==l}" if @debug
        t == l ? t : nil
      }
    end

    def next_lit(options = {})
      lit = nil
      pos0 = @pos
      return nil if eof?
      while lit = next_input_element(options)
        if lit and (lit.ws? or lit.lf?)
          ;
        else
          break
        end
      end
      @pos = pos0
      lit
    end

    def fwd_lit(options = {})
      lit = nil
      return nil if eof?
      if options[:nolt]
        while lit = next_input_element(options)
          if lit and lit.ws?
            ;
          else
            break
          end
        end
      else
        while lit = next_input_element(options)
          if lit and (lit.ws? or lit.lf?)
            ;
          else
            break
          end
        end
      end
      lit
    end

    def ws_lit(options = {})
      ret = next_input_element(options)
      if ret.ws? or ret.lf?
        ret
      else
        nil
      end
    end

    def rewind_pos
      if @pos > 0
        @pos -= 1
      end
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
          @error_pos = @pos
          @pos = saved_pos
          nil
        end
      end
    end
  end
end
