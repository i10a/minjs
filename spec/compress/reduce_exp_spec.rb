# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'ReduceExpression' do
    it 'reduce strict equles operators to non-strict operators' do
      c = test_compressor
      c.parse <<-EOS
typeof A === "string";
typeof A !== "string";
+A === 0;
(a="0") === "0"
EOS
      js = c.reduce_exp.to_js
      expect(js).to eq "typeof A==\"string\";typeof A!=\"string\";+A==0;(a=\"0\")==\"0\";"
    end

    it 'reduce to assignment expression' do
      c = test_compressor
      c.parse <<-EOS
a = a / 2
a = a * 2
a = a % 2
a = a + 2
a = a - 2
a = a << 2
a = a >> 2
a = a >>> 2
a = a & 2
a = a | 2
a = a ^ 2
EOS
      js = c.reduce_exp.to_js
      expect(js).to eq "(a/=2);(a*=2);(a%=2);(a+=2);(a-=2);(a<<=2);(a>>=2);(a>>>=2);(a&=2);(a|=2);(a^=2);"
    end

    it 'reduce logical not expression' do
      c = test_compressor
      c.parse "! ! ! !a; ! ! ! ! 0; ! ! ! 1234;! ! ! ! !{}"
      js = c.reduce_exp.to_js
      expect(js).to eq "!!a;!1;!1;!{};"
    end

    it 'reduce add expression' do
      c = test_compressor
      c.parse <<-EOS
1+0;
0+2;
1+3;
1.4+3.5;
"a"+"b"
EOS
      js = c.reduce_exp.to_js
      expect(js).to eq "1;2;4;4.9;\"ab\";"
    end

  end
end

