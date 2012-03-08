require 'spec_helper'

describe Transactional::TDir do
  let(:tdir) { Transactional::TDir.new(filesystem_root, testdir_rpath) }

  before { create_empty_filesytem }

  context "when a directory is created" do
    before { tdir.create }
    it "creates a directory" do
      testdir.should be_present
    end

    it "deletes the directory when rolled back" do
      tdir.rollback
      testdir.should_not be_present
    end
  end

  context "when no directory is created" do
    it "does nothing when rolled back" do
      tdir.rollback
      testdir.should_not be_present
    end
  end
end
