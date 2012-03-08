require 'spec_helper'

describe Transactional::Transaction do
  let(:transaction) { Transactional::Transaction.new }
  let(:filesystem1) { transaction.create_file_system(filesystem_root) }
  let(:filesystem2) { transaction.create_file_system(filesystem_root) }

  before do
    Transactional::FileSystem.stub(:new).
      and_return(mock("filesystem 1"), mock("filesystem 2"))
  end

  [:commit, :rollback].each do |operation|
    it "#{operation}s all filesystems on #{operation}" do
      filesystem1.should_receive(operation)
      filesystem2.should_receive(operation)
      transaction.send operation
    end
  end
end