require 'spec_helper'

describe 'Statement' do
  describe 'Try' do
    it 'is try-catch statement' do
      js = test_parse <<-EOS
try{
throw 'a'
}
catch(e){
console.log(e)
}
EOS
      expect(js).to eq "try{throw\"a\"}catch(e){console.log(e)}"
    end

    it 'is try-finally statement' do
      js = test_parse <<-EOS
try{
try{
throw "a"
}
finally{
console.log("f")
}
}
catch(e){
}
EOS
      expect(js).to eq "try{try{throw\"a\"}finally{console.log(\"f\")}}catch(e){}"
    end

    it 'is try-catch-finally statement' do
      js = test_parse <<-EOS
try{
throw 'a';
var a=1;
}
catch(e){
console.log(e)
}
finally{
console.log(a)//undefined
}
EOS
      expect(js).to eq "try{throw\"a\";var a=1}catch(e){console.log(e)}finally{console.log(a)}"
    end
  end
end
