require 'spec_helper'


describe Transactional do
  let(:filesystem_root) {File.join(SPEC_HOME, "test_filesystem")}
  let(:testfile_name)   {"testfile"}
  let(:testfile_path)   {File.join(filesystem_root, testfile_name)}

  describe "writing a file inside a transaction" do
    before do
      if File.directory? filesystem_root
        FileUtils.rm_rf filesystem_root
      end
      FileUtils.mkdir filesystem_root
    end

    context "when the transaction is sucessful" do
      it "creates a new file" do
        include Transactional
        Transactional::start_transaction do
          filesystem = Transactional::create_filesystem(filesystem_root)
          filesystem.create_file testfile_name
        end

        File.exists?(testfile_path).should be_true
      end
    end
  end

  describe Transactional::FileSystem do
    before do
      @filesystem = Transactional::FileSystem.new(filesystem_root)
    end

    it "creates a file" do
      File.should_receive(:open).with(testfile_path, "w")
      @filesystem.create_file "testfile"
    end
  end
end