require 'spec_helper'

describe Transactional::FileSystem do
  before { create_empty_filesytem }
  after  { lockfile.should_not be_present }

  let(:transaction) { mock("a transaction") }
  let(:filesystem)  { Transactional::FileSystem.new(transaction, filesystem_root) }

  it "writes a file on commit" do
    filesystem.open testfile_rpath
    filesystem.commit
    testfile.should be_present
  end

  it "rolls back a file" do
    filesystem.open testfile_rpath
    filesystem.rollback
    testfile.should_not be_present
  end

  context "when an error occurs on a file operation" do
    it "rolls back its parent transaction" do
      File.any_instance.stub(:open).and_raise(Exception.new("something went wrong"))
      transaction.should_receive(:rollback)
      filesystem.open(testfile_rpath) do |f|
        f.open
      end
      filesystem.commit
    end
  end
end