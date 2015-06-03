# coding: utf-8
require 'spec_helper'

describe 'Literal' do
  describe 'Object' do
    it 'is object literal' do
      js = test_parse <<-EOS
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
      expect(js).to eq "a={a:1,b:2,c:3};b={a:1,b:2,c:3};c={a:1,b:2,c:3};d={a:1,b:2,c:3};e={\"\":1};c={a:1,b:2,c:3};d={a:1,b:2,c:3};e={\"\":1};f={あ:\"a\"};"
    end

    it 'is object literal with numeric key' do
      js = test_parse <<-EOS
g={365: "decimal",
0xff: "hex",
3.14: "float",
1e10: "exp",
123456789012345678901: "big e<=21",
1234567890123456789012: "big e>=21",
123.4567890123456789012: "e=0",
0.000001234567890123456789012: "e>=-6",
0.0000000001234567890123456789012: "e<=-6",
1e500: "+Inf",
1e-500: "-Inf",
}
console.log(g)
EOS
      expect(js).to eq "g={365:\"decimal\",255:\"hex\",3.14:\"float\",10000000000:\"exp\",123456789012345680000:\"big e<=21\",1.2345678901234568e+21:\"big e>=21\",123.45678901234568:\"e=0\",0.0000012345678901234567:\"e>=-6\",1.2345678901234568e-10:\"e<=-6\",Infinity:\"+Inf\",0:\"-Inf\"};console.log(g);"

    end

    it 'is object literal' do
      js = test_parse <<-EOS
h={if:'if',true:'true',null:'null'}
console.log(h)
EOS
      expect(js).to eq "h={if:\"if\",true:\"true\",null:\"null\"};console.log(h);"
    end

    it 'is object literal' do
      js = test_parse <<-EOS
h={
a: 'a',
a: 'b',
a: 'c',
}
console.log(h)
EOS
      expect(js).to eq "h={a:\"a\",a:\"b\",a:\"c\"};console.log(h);"
    end

    it 'is object literal with getter/setter' do
      js = test_parse <<-'EOS'
h ={
get a(){return new Date()},
set a(v){val=v},
get: a,//get and set are not reserved word
set: b
}
console.log(h.a)
EOS
      expect(js).to eq "h={get a(){return new Date()},set a(v){val=v},get:a,set:b};console.log(h.a);"
    end
  end
end
