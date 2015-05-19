# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'RemoveParen' do
    it 'remove paren' do
      c = test_compressor
      c.parse <<-EOS
(!0)+a
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "!0+a;"
    end

    it 'remove paren of for statemetns' do
      c = test_compressor
      c.parse <<-'EOS'
for((a,b);(c,d);(e,f))
;
for(var a=(1);(c,d);(e,f))
;
for((a) in (a,b))
;
for(var a=(1) in (a,b))
;
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "for(a,b;c,d;e,f);for(var a=1;c,d;e,f);for(a in a,b);for(var a=1 in a,b);"
    end
    it 'remove paren of switch statements' do
      c = test_compressor
      c.parse <<-'EOS'
switch((1,2)){
case (1,2):
;
}
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "switch(1,2){case 1,2:}"
    end

    it 'remove paren of statements' do
      c = test_compressor
      c.parse <<-'EOS'
var a=(1),b=(1,2);
if((1,2));
do{}while((1,2));
while((1,2)){};
return (1,2);
with((1,2)){};
throw (1,2);
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "var a=1,b=(1,2);if(1,2);do{}while(1,2);while(1,2){}return 1,2;with(1,2){}throw(1,2);";
    end

    it 'remove paren of primary expression' do
      c = test_compressor
      c.parse <<-EOS
(this);
(foo);
(0);
(3.14);
("aaa");
(/regexp/);
(null);
(true);
(false);
([1,2,3]);
//({a:b, c:d}); =>  not remove
a=({a:b, c:d});
((((('a')))));
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "this;foo;0;3.14;\"aaa\";/regexp/;null;true;false;[1,2,3];a={a:b,c:d};\"a\";"
    end

    it 'remove paren of left-hand-side operators' do
      c = test_compressor
      c.parse <<-EOS
(a)[0];
(a).b;
new (A);
new (A)(a,b,c);
new (A)(a,(b?c:d),(c,d));
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a[0];a.b;new A;new A(a,b,c);new A(a,b?c:d,(c,d));";
    end

    it 'remove paren of postfix operators' do
      c = test_compressor
      c.parse <<-EOS
(a)++;
(b[0])--;
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a++;b[0]--;"
    end

    it 'remove paren of unary operators' do
      c = test_compressor
      c.parse <<-EOS
+(a*b);
+(a++);//remove
+(++a);//remove
(+ a)++;
+(a[0]);//remove
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "+(a*b);+a++;+ ++a;(+a)++;+a[0];"
    end

    it 'remove paren of multiplicative operators ' do
      c = test_compressor
      c.parse <<-EOS
(a*b)*c;
a*(b*c);// does not remove
a*(!b);
(a/b)/c;
a/(b/c);// does not remove
a/(!b);
(a%b)%c;
a%(b%c);// does not remove
a%(!b);
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a*b*c;a*(b*c);a*!b;a/b/c;a/(b/c);a/!b;a%b%c;a%(b%c);a%!b;"
    end

    it 'remove paren of additive operators ' do
      c = test_compressor
      c.parse <<-EOS
(a+b)+c;
a+(b+c);// does not remove
a+(b*c);
(a-b)-c;
a-(b-c);// does not remove
a-(b*c);
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a+b+c;a+(b+c);a+b*c;a-b-c;a-(b-c);a-b*c;"
    end

    it 'remove paren of relational operators' do
      c = test_compressor
      c.parse <<-EOS
(a+b)<<(c+d)>>(e+f)>>>(g+h);
(a<<b)<(c<<d);
(a<<b)>(c<<d);
(a<<b)<=(c<<d);
(a<<b)>=(c<<d);
(a<<b)instanceof(c<<d);
(a<<b)in(c<<d);
(a==b)in(c==d);
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a+b<<c+d>>e+f>>>g+h;a<<b<c<<d;a<<b>c<<d;a<<b<=c<<d;a<<b>=c<<d;a<<b instanceof c<<d;a<<b in c<<d;(a==b)in(c==d);"
    end

    it 'remove paren of equality operators' do
      c = test_compressor
      c.parse <<-EOS
(a>b)==(c<d);//remove
(a&b)==(c&d);
(a>b)!=(c<d);//remove
(a&b)!=(c&d);
(a>b)===(c<d);//remove
(a&b)===(c&d);
(a>b)!==(c<d);//remove
(a&b)!==(c&d);
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a>b==c<d;(a&b)==(c&d);a>b!=c<d;(a&b)!=(c&d);a>b===c<d;(a&b)===(c&d);a>b!==c<d;(a&b)!==(c&d);"
    end

    it 'remove paren of binary bitwise operators' do
      c = test_compressor
      c.parse <<-EOS
(a==b)&(c==d);//remove
(a^b)&(c^d);
(a|b)&(c|d);
(a&b)^(c&d);//remove
(a|b)^(c|d);
(a&b)|(c&d);//remove
(a^b)|(c^d);//remove
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a==b&c==d;(a^b)&(c^d);(a|b)&(c|d);a&b^c&d;(a|b)^(c|d);a&b|c&d;a^b|c^d;";
    end

    it 'remove paren of binary logical operators' do
      c = test_compressor
      c.parse <<-EOS
(a&&b)||(b&&c);//remove
(a||b)&&(b||c);
(a&b)||(b&c);//remove
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a&&b||b&&c;(a||b)&&(b||c);a&b||b&c;"
    end

    it 'remove paren of conditional operators' do
      c = test_compressor
      c.parse <<-EOS
(a||b)?(a=1):(b=2);//remove all paren
(a=b)?(a=1,b=2):(b=2)//remove 3rd paren
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a||b?a=1:b=2;(a=b)?(a=1,b=2):b=2;"
    end

    it 'remove paren for assignment operator' do
      c = test_compressor
      c.parse <<-EOS
a=(b?c:d);//remove
a=(b,c);
(a)=(b,c);//left-hand remove
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "a=b?c:d;a=(b,c);a=(b,c);"
    end

    it 'does not remove paren which include object literal' do
      c = test_compressor
      c.parse <<-EOS
// ECMA262 say, expression statement cannot start with an opening curly brace
({a:'b'})
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "({a:\"b\"});"
    end

    it 'does not remove paren which include function expression' do
      c = test_compressor
      c.parse <<-EOS
// ECMA262 say, expression statement cannot start with the function keyword
(function(a,b){console.log(a,b)}(1,2))
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "(function(a,b){console.log(a,b)}(1,2));"
    end
  end
end
