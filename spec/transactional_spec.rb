require 'spec_helper'

describe Transactional do
  before { create_empty_filesytem }
  after  { lockfile.should_not be_present }

  describe "Integration Tests" do
    describe "creating a directory inside a filesystem" do
      it "creates a directory" do
        start_transaction do |filesystem, transaction|
          filesystem.create_directory testdir_rpath
        end
        testdir.should be_present
      end

      context "when the transaction fails" do
        it "deletes the directory" do
          pending "making a TDir rollback"
          start_transaction do |filesystem, transaction|
            filesystem.create_directory testdir_rpath
            transaction.rollback
          end
          testdir.should_not be_present
        end
      end
    end

    describe "writing a file inside a transaction" do
      context "when the transaction is sucessful" do
        it "creates a new file" do
          start_transaction do |filesystem, transaction|
            filesystem.open testfile_rpath
            testfile.should be_present
          end
          testfile.should be_present
          testfile.should be_empty
        end

        it "overwrites an existing file" do
          testfile.data = "hello world"
          start_transaction do |filesystem, transaction|
            filesystem.open(testfile_rpath) do |f|
              f.print "goodbye world"
            end
          end
          testfile.data.should == "goodbye world"
        end
      end

      context "when the transaction is rolled back" do
        context "and the file was created inside the transaction" do
          it "it deletes the file" do
            start_transaction do |filesystem, transaction|
              filesystem.open testfile_rpath

              testfile.should be_present
              testfile.should be_empty
              transaction.rollback
              testfile.should_not be_present
            end
            testfile.should_not be_present
          end

          it "deletes the lock file" do
            start_transaction do |filesystem, transaction|
              filesystem.open testfile_rpath do |f|
                lockfile.should be_present
                transaction.rollback
              end
            end
            lockfile.should_not be_present
          end
        end

        context "and the file existed before the transaction" do
          it "rolls and existing file back to its original data" do
            testfile.data = "hello world"
            start_transaction do |filesystem, transaction|
              filesystem.open(testfile_rpath) do |f|
                f.print "goodbye world"
              end
              transaction.rollback
            end
            testfile.data.should == "hello world"
          end

          it "deletes the lock file" do
            testfile.data = "hello world"
            start_transaction do |filesystem, transaction|
              filesystem.open(testfile_rpath) do |f|
                f.print "goodbye world"
                lockfile.should be_present
                transaction.rollback
              end
            end
            lockfile.should_not be_present
          end
        end
      end

      context "when an error causes the transaction to fail" do
        before do
          File.stub(:open).and_raise(Exception.new("something went wrong"))
        end

        it "rolls back the transaction" do
          start_transaction do |filesystem, transaction|
            transaction.should_receive(:rollback)

            filesystem.open(testfile_rpath) do |f|
              f.print "goodbye world"
            end
          end
        end
      end
    end
  end
end
