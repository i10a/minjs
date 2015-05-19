require 'spec_helper'

describe 'Statement' do
  describe 'Block' do
    it 'is empty block' do
      js = test_parse <<-EOS
{}
EOS
      expect(js).to eq "{}"
    end
    it 'is simple block' do
      js = test_parse <<-EOS
{
console.log('1');
console.log('2');
}
EOS
      expect(js).to eq "{console.log(\"1\");console.log(\"2\")}"
    end
    it 'is block in block' do
      js = test_parse <<-EOS
{{
console.log('1');
console.log('2');
}}
EOS
      expect(js).to eq "{{console.log(\"1\");console.log(\"2\")}}"
    end
  end
end
