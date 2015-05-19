require 'spec_helper'

describe 'Statement' do
  describe 'Continue' do
    it 'is continue statement' do
      js = test_parse <<-EOS
i=0;
while(i<10){
  i+=1
  if(i>5)
    continue;
  console.log(i)
}
EOS
      expect(js).to eq "i=0;while(i<10){i+=1;if(i>5)continue;console.log(i)}"
    end

    it 'is continue statement with label' do
      js = test_parse <<-EOS
j=0
undefined:
while(j<10){
    ++j;
    i=0;
    while(i<10){
	++i;
	if(i<5)
	    continue undefined;
        console.log(i, j)
    }
}
EOS
      expect(js).to eq "j=0;undefined:while(j<10){++j;i=0;while(i<10){++i;if(i<5)continue undefined;console.log(i,j)}}"
    end

    it 'is continue statement with automatic semicolon insertion' do
      js = test_parse <<-EOS
j=0;
undefined:
while(j<10){
    ++j;
    i=0;
    while(i<10){
        ++i;
	if(i<5)
	    continue
		 undefined;//ignored
        console.log(j)
    }
}
EOS
      expect(js).to eq "j=0;undefined:while(j<10){++j;i=0;while(i<10){++i;if(i<5)continue;undefined;console.log(j)}}"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse <<-EOS
continue this//this is not identifier
EOS
      }.to raise_error(Minjs::ParseError)
    end
  end
end
