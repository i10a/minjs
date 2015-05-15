require 'spec_helper'

describe 'Statement' do
  describe 'Throw' do
    it 'is throw statement' do
      js = test_parse <<-EOS
try{
throw 'a'
}
catch(e){
console.log(e)
}
EOS
      expect(js).to eq "try{throw\"a\"}catch(e){console.log(e)};"
    end

    it 'cause syntax error' do
      expect {
        js = test_parse <<-EOS
throw
EOS
      }.to raise_error(Minjs::ParseError)
    end

    it 'cause syntax error' do
      expect {
        js = test_parse <<-EOS
throw//no line terminator here
a
EOS
      }.to raise_error(Minjs::ParseError)
    end

    it 'cause syntax error' do
      expect {
        js = test_parse <<-EOS
throw 1+;// bad expression
EOS
      }.to raise_error(Minjs::ParseError)
    end
  end
end
