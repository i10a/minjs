require 'spec_helper'

describe 'Statement' do
  describe 'With' do
    it 'is with statement' do
      js = test_parse <<-EOS
o={a:1};
with(o){
    console.log(a)
    a=2;
    console.log(a)
}
console.log(o)// => {a:2}
EOS
      expect(js).to eq "o={a:1};with(o){console.log(a);a=2;console.log(a)}console.log(o);"
    end
  end
end
