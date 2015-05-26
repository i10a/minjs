# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'ReduceExpression' do
    it 'reduces strict equles operators to non-strict operators' do
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

    it 'reduces to assignment expression' do
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

    it 'reduces logical not expression' do
      c = test_compressor
      c.parse "! ! ! !a; ! ! ! ! 0; ! ! ! 1234;! ! ! ! !{}"
      js = c.reduce_exp.to_js
      expect(js).to eq "!!a;!1;!1;!{};"
    end

    it 'reduces addtive expression' do
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

    it 'reduces addtive expression and results are string' do
      c = test_compressor
      c.parse <<-EOS
"a"+undefined
"a"+null
"a"+false
"a"+true
"a"+0.4
"a"+{}
undefined+'A'
null+'A'
false+'A'
true+'A'
0.4+'A'
{}+'A'
EOS
      js = c.reduce_exp.to_js
      expect(js).to eq ('"a"+undefined;"anull";"afalse";"atrue";"a0.4";"a"+{};' +
                        'undefined+"A";"nullA";"falseA";"trueA";"0.4A";{}+"A";')
    end

    it 'reduces expression and results are number' do
      c = test_compressor
      c.parse <<-EOS
1+4;
1e3+4.4e4;
1+true;
2+null;
3+false;
true+false;
true*true;
3.14*2.718;
true-null;
EOS
      js = c.reduce_exp.to_js
      expect(js).to eq ('5;45e3;2;2;3;1;1;8.53452;1;')
    end

    it 'reduces expression with string and results are number' do
      c = test_compressor
      c.parse <<-'EOS'
"1"-true //0
"  3.14"-true //=>2.14 preceded by white space
"2.71\n  "-true //=>1.71 followed by white space
" 0001000 "-true //=>999 leading 0 digits
"+50"-true //=>49 plus sign
"-50"-true //=>51 minus sign
"1.23e4"*"10" //=>123e3
"1.23e+4"*"10" //=>123e3
"1.23e-4"-"10" //=>-9.999877;
" " - "1" //-1
"" - "1" //-1
"A" - 1 // NaN
EOS
      js = c.reduce_exp.to_js
      expect(js).to eq ('0;2.14;1.71;999;49;-51;123e3;123e3;-9.999877;-1;-1;"A"-1;')
    end
  end
end

