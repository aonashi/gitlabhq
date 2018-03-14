module Lfs
  # Usage: Calling `new_file` check to see if a file should be in LFS and
  #        return a transformed result with `content` and `encoding` to commit.
  #
  #        For LFS an LfsObject linked to the project is stored and an LFS
  #        pointer returned. If the file isn't in LFS the untransformed content
  #        is returned to save in the commit.
  #
  # transformer = Lfs::FileTransformer.new(project, @branch_name)
  # content_or_lfs_pointer = transformer.new_file(file_path, content).content
  # create_transformed_commit(content_or_lfs_pointer)
  #
  class FileTransformer
    attr_reader :project, :branch_name

    delegate :repository, to: :project

    def initialize(project, branch_name)
      @project = project
      @branch_name = branch_name
    end

    def new_file(file_path, file_content)
      if project.lfs_enabled? && lfs_file?(file_path)
        lfs_pointer_file = Gitlab::Git::LfsPointerFile.new(file_content)
        lfs_object = create_lfs_object!(lfs_pointer_file, file_content)

        link_lfs_object!(lfs_object)

        lfs_pointer_file.pointer
      else
        file_content
      end
    end

    private

    def lfs_file?(file_path)
      repository.attributes_at(branch_name, file_path)['filter'] == 'lfs'
    end

    def create_lfs_object!(lfs_pointer_file, file_content)
      LfsObject.find_or_create_by(oid: lfs_pointer_file.sha256, size: lfs_pointer_file.size) do |lfs_object|
        lfs_object.file = CarrierWaveStringFile.new(file_content)
      end
    end

    def link_lfs_object!(lfs_object)
      project.lfs_objects << lfs_object
    end
  end
end
