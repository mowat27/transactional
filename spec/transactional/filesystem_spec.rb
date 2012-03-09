require 'spec_helper'

describe Transactional::FileSystem do
  let(:transaction) { mock("a transaction") }
  let(:root) { Transactional::Test::TestDir.new(filesystem_root) }
  let(:filesystem)  { Transactional::FileSystem.new(transaction, filesystem_root) }

  context "when the root does not exist" do
    before { delete_test_filesystem }

    describe "#create" do
      it "creates the filesystem root" do
        filesystem.create
        root.should be_present
      end
    end
  end

  context "when the root exists" do
    before { reset_test_filesytem }
    after  { lockfile.should_not be_present }

    let(:filesystem)  { Transactional::FileSystem.new(transaction, filesystem_root) }

    describe "#create" do
      it "does nothing" do
        filesystem.create
        root.should be_present
      end
    end

    context "on commit" do
      it "writes files" do
        filesystem.open testfile_rpath
        filesystem.commit
        testfile.should be_present
      end

      it "writes directories" do
        filesystem.create_directory testdir_rpath
        filesystem.commit
        testdir.should be_present
      end
    end

    context "on rollback" do
      it "rolls back files" do
        filesystem.open testfile_rpath
        filesystem.rollback
        testfile.should_not be_present
      end

      it "rolls back directories" do
        filesystem.create_directory testdir_rpath
        filesystem.rollback
        testdir.should_not be_present
      end
    end

    context "when an error occurs during a filesystem operation" do
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
end