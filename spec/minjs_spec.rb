# coding: utf-8
require 'spec_helper'

describe Minjs do
  it 'has a version number' do
    expect(Minjs::VERSION).not_to be nil
  end

  it 'is regexp literal' do
    js = Minjs::Compressor.new.parse <<-EOS
a=/abc/;
b=/a\\bc/;
c=/a\\/c/;
d=/a[bc]d/;
e=/a[\\bc]d/;
f=/a[\\bc/]d/;
a=/abc/g;
b=/a\\bc/g;
c=/a\\/c/g;
d=/a[bc]d/g;
e=/a[\\bc]d/g;
f=/a[\\bc/]d/g;
EOS
    expect(js).not_to be nil
  end

  it 'is singleline comment literal' do
    js = Minjs::Compressor.new.parse <<-EOS
// singleline
// singleline (no lt)
EOS
    expect(js.to_js).to eq (";")
  end

  it 'is multiline comment literal' do
    js = Minjs::Compressor.new.parse <<-EOS
/* single line */
/*
multiline
*/
EOS
    expect(js.to_js).to eq (";")
  end

  it 'is multiline comment and treated as white space' do
    js = Minjs::Compressor.new.parse <<-EOS
return /* multiline */1+2
EOS
    expect(js.to_js).to eq("return 1+2;")
  end

  it 'is multiline comment and treated as line terminator' do
    js = Minjs::Compressor.new.parse <<-EOS
return /* multiline
*/1+2
EOS
    expect(js.to_js).to eq("return;1+2;")
  end

  it 'is string literal' do
    js = Minjs::Compressor.new.parse <<-EOS
a=""
a="abc"
a="a\\nbc"
a="a\\u0042c"
a="a\\x42c"
a="a\\102c"
a="あいうえお"
EOS
    expect(js.to_js).to eq('a="";a="abc";a="a\nbc";a="aBc";a="aBc";a="aB";a="あいうえお";')
  end

  it 'is numeric literal' do
    js = Minjs::Compressor.new.parse <<-EOS
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
    expect(js.to_js).to eq "console.log(.123);console.log(.456e10);console.log(.456e10);console.log(.789e-10);console.log(1.123);console.log(1.456e10);console.log(1.456e10);console.log(1.789e-10);console.log(2);console.log(2e10);console.log(2e10);console.log(2748);console.log(2748);"
  end

  it 'is array literal' do
    js = Minjs::Compressor.new.parse <<-EOS
a=[1,2,3]
b=["a","b","c"]
c=[1,,3]
d=[1,2,3,]
EOS
    expect(js.to_js).to eq "a=[1,2,3];b=[\"a\",\"b\",\"c\"];c=[1,,3];d=[1,2,3];"
  end

  it 'is object literal' do
    js = Minjs::Compressor.new.parse <<-EOS
a={a:1, b:2, c:3}
b={a:1, b:2, c:3,}
c={"a":1, "b":2, "c":3}
d={"a":1, "b":2, "c":3,}
e={"":1}
c={'a':1, 'b':2, 'c':3}
d={'a':1, 'b':2, 'c':3,}
e={'':1}
f={あ:'a'}
EOS
    expect(js.to_js).to eq "a={a:1,b:2,c:3};b={a:1,b:2,c:3};c={a:1,b:2,c:3};d={a:1,b:2,c:3};e={\"\":1};c={a:1,b:2,c:3};d={a:1,b:2,c:3};e={\"\":1};f={あ:\"a\"};"
  end

  it 'is object literal' do
    js = Minjs::Compressor.new.parse <<-EOS
g={0:1, 0x1:2, 3.14:3, 1e10:4}
console.log(g)
EOS
    expect(js.to_js).to eq "g={0:1,0x1:2,3.14:3,1e10:4};console.log(g);"
  end

  it 'is object literal' do
    js = Minjs::Compressor.new.parse <<-EOS
h={if:'if',true:'true',null:'null'}
console.log(h)
EOS
    expect(js.to_js).to eq "h={if:\"if\",true:\"true\",null:\"null\"};console.log(h);"
  end

end
