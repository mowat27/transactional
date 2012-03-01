require 'spec_helper'


describe Transactional do
  let(:filesystem_root) { File.join(SPEC_HOME, "test_filesystem") }
  let(:testfile_name)   { "testfile" }
  let(:testfile_path)   { File.join(filesystem_root, testfile_name) }

  describe "writing a file inside a transaction" do
    before do
      if File.directory? filesystem_root
        FileUtils.rm_rf filesystem_root
      end
      FileUtils.mkdir filesystem_root
    end

    context "when the transaction is sucessful" do
      it "creates a new file" do
        Transactional::start_transaction do |transaction|
          filesystem = transaction.create_filesystem(filesystem_root)
          filesystem.create_file testfile_name

          File.exists?(testfile_path).should be_true
        end
        File.exists?(testfile_path).should be_true
      end
    end

    context "when the transaction fails" do
      it "it rolls back the file" do
        Transactional::start_transaction do |transaction|
          filesystem = transaction.create_filesystem(filesystem_root)
          filesystem.create_file testfile_name

          File.exists?(testfile_path).should be_true
          transaction.rollback
          File.exists?(testfile_path).should be_false
        end
        File.exists?(testfile_path).should be_false
      end
    end
  end

  describe Transactional::FileSystem do
    before do
      @filesystem = Transactional::FileSystem.new(filesystem_root)
    end

    it "creates a file" do
      File.should_receive(:open).with(testfile_path, "w")
      @filesystem.create_file testfile_name
    end
  end
end