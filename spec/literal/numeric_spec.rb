# coding: utf-8
require 'spec_helper'

describe 'Literal' do
  describe 'Numeric' do
    it 'is numeric literal' do
      js = test_parse <<-EOS
console.log(.123)
console.log(.456e10)
console.log(.456e+10)
console.log(.789e-10)
console.log(1.123)
console.log(1.456e10)
console.log(1.456e+10)
console.log(1.789e-10)
console.log(2.)
console.log(2.e10)
console.log(2e10)
console.log(0xabc)
console.log(0XABC)
EOS
      expect(js).to eq "console.log(.123);console.log(.456e10);console.log(.456e10);console.log(.789e-10);console.log(1.123);console.log(1.456e10);console.log(1.456e10);console.log(1.789e-10);console.log(2);console.log(2e10);console.log(2e10);console.log(2748);console.log(2748);"
    end

    it 'is numeric literal which integer part is zero' do
      js = test_parse "a=0;b=0.1;c=0e1;d=0.2e-2;"
      expect(js).to eq "a=0;b=.1;c=0;d=.002;"
    end

    it 'is octal integer' do
      js = test_parse "a=017;"
      expect(js).to eq "a=15;"
    end

    it 'raise error' do
      expect {
        js = test_parse <<-EOS
a=018
EOS
      }.to raise_error(Minjs::ParseError)
    end
  end
end
