# frozen_string_literal: true

namespace :tailwindcss do
  desc "Link installed engines so Tailwind @source paths do not depend on the Bundler checkout directory"
  task link_engine_sources: :environment do
    destination = Rails.root.join("vendor/engines")
    FileUtils.mkdir_p(destination)

    {
      "flat_pack" => FlatPack::Engine.root,
      "recording_studio" => RecordingStudio::Engine.root
    }.each do |name, engine_root|
      link = destination.join(name)
      target = Pathname.new(engine_root).realpath

      if link.symlink?
        current = Pathname.new(File.readlink(link))
        current = (link.dirname / current).cleanpath unless current.absolute?
        next if current == target

        link.delete
      elsif link.exist?
        raise "#{link} exists and is not a symlink to #{target}"
      end

      File.symlink(target, link)
    end
  end
end

%w[tailwindcss:build tailwindcss:watch].each do |task_name|
  next unless Rake::Task.task_defined?(task_name)

  Rake::Task[task_name].enhance([ "tailwindcss:link_engine_sources" ])
end
